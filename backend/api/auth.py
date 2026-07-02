from fastapi import APIRouter, Depends, HTTPException, Request, status
from pydantic import BaseModel, Field, field_validator
from sqlalchemy.orm import Session

from database.db import get_db
from database.models import User
from utils.jwt_auth import create_access_token, get_current_user
from utils.passwords import hash_password, verify_password
from utils.rate_limit import REGISTER_LIMIT, LOGIN_LIMIT, limiter
from utils.validators import (
    validate_email,
    validate_full_name,
    validate_password_login,
    validate_password_register,
)

router = APIRouter(prefix="/auth", tags=["Auth"])


class RegisterRequest(BaseModel):
    email: str = Field(..., min_length=3, max_length=255)
    password: str = Field(..., min_length=8, max_length=128)
    full_name: str = Field(..., min_length=1, max_length=255)

    @field_validator("email")
    @classmethod
    def check_email(cls, value: str) -> str:
        return validate_email(value)

    @field_validator("password")
    @classmethod
    def check_password(cls, value: str) -> str:
        return validate_password_register(value)

    @field_validator("full_name")
    @classmethod
    def check_full_name(cls, value: str) -> str:
        return validate_full_name(value)


class LoginRequest(BaseModel):
    email: str = Field(..., min_length=3, max_length=255)
    password: str = Field(..., min_length=1, max_length=128)

    @field_validator("email")
    @classmethod
    def check_email(cls, value: str) -> str:
        return validate_email(value)

    @field_validator("password")
    @classmethod
    def check_password(cls, value: str) -> str:
        return validate_password_login(value)


class UserResponse(BaseModel):
    user_id: str
    email: str
    full_name: str | None


class AuthResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserResponse


def _user_response(user: User) -> UserResponse:
    return UserResponse(
        user_id=user.user_id,
        email=user.email,
        full_name=user.full_name,
    )


@router.post("/register", response_model=AuthResponse, status_code=status.HTTP_201_CREATED)
@limiter.limit(REGISTER_LIMIT)
def register(request: Request, body: RegisterRequest, db: Session = Depends(get_db)):

    if db.query(User).filter(User.email == body.email).first():
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="An account with this email already exists.",
        )

    user = User(
        email=body.email,
        password_hash=hash_password(body.password),
        full_name=body.full_name,
    )
    db.add(user)
    db.commit()
    db.refresh(user)

    token = create_access_token(user_id=user.user_id, email=user.email)
    return AuthResponse(access_token=token, user=_user_response(user))


@router.post("/login", response_model=AuthResponse)
@limiter.limit(LOGIN_LIMIT)
def login(request: Request, body: LoginRequest, db: Session = Depends(get_db)):

    user = db.query(User).filter(User.email == body.email).first()
    if user is None or not verify_password(body.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password.",
        )

    token = create_access_token(user_id=user.user_id, email=user.email)
    return AuthResponse(access_token=token, user=_user_response(user))


@router.get("/me", response_model=UserResponse)
def me(current_user: User = Depends(get_current_user)):
    return _user_response(current_user)


class UpdateProfileRequest(BaseModel):
    full_name: str | None = Field(None, min_length=1, max_length=255)
    email: str | None = Field(None, min_length=3, max_length=255)
    current_password: str | None = Field(None, min_length=1, max_length=128)
    new_password: str | None = Field(None, min_length=8, max_length=128)

    @field_validator("email")
    @classmethod
    def check_email(cls, value: str | None) -> str | None:
        if value is None:
            return value
        return validate_email(value)

    @field_validator("full_name")
    @classmethod
    def check_full_name(cls, value: str | None) -> str | None:
        if value is None:
            return value
        return validate_full_name(value)

    @field_validator("new_password")
    @classmethod
    def check_new_password(cls, value: str | None) -> str | None:
        if value is None:
            return value
        return validate_password_register(value)


@router.patch("/profile", response_model=AuthResponse)
def update_profile(
    body: UpdateProfileRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    # If changing password, require current_password and verify it
    if body.new_password is not None:
        if not body.current_password:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Current password is required to set a new password.",
            )
        if not verify_password(body.current_password, current_user.password_hash):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Current password is incorrect.",
            )
        current_user.password_hash = hash_password(body.new_password)

    # If changing email, check it's not already taken
    if body.email is not None and body.email != current_user.email:
        if db.query(User).filter(User.email == body.email).first():
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="An account with this email already exists.",
            )
        current_user.email = body.email

    if body.full_name is not None:
        current_user.full_name = body.full_name

    db.commit()
    db.refresh(current_user)

    # Issue a fresh token (email may have changed)
    token = create_access_token(
        user_id=current_user.user_id, email=current_user.email
    )
    return AuthResponse(access_token=token, user=_user_response(current_user))
