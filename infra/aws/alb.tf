# ── Application Load Balancer ─────────────────────────────────────────────────
# Public-facing. Handles TLS termination and routes traffic to ECS tasks.

resource "aws_lb" "api" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  # Access logs — optional; uncomment to enable.
  # access_logs {
  #   bucket  = aws_s3_bucket.storage.bucket
  #   prefix  = "alb-logs"
  #   enabled = true
  # }

  tags = { Name = "${var.project_name}-alb" }
}

# ── Target Group ─────────────────────────────────────────────────────────────
# ECS tasks register themselves here. The ALB health-checks /health and only
# routes traffic to tasks that return 200.

resource "aws_lb_target_group" "api" {
  name        = "${var.project_name}-tg"
  port        = var.app_port
  protocol    = "HTTP"
  target_type = "ip" # required for Fargate (tasks have no EC2 instance IDs)
  vpc_id      = aws_vpc.main.id

  health_check {
    enabled             = true
    path                = "/health"
    protocol            = "HTTP"
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }

  # Drain connections for 30 s before killing a task during deploys.
  deregistration_delay = 30

  tags = { Name = "${var.project_name}-tg" }
}

# ── Listener: HTTP → HTTPS redirect ──────────────────────────────────────────
# All plain HTTP traffic is permanently redirected to HTTPS.

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.api.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# ── Listener: HTTPS → ECS ─────────────────────────────────────────────────────
# Terminates TLS using the ACM certificate and forwards to the target group.

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.api.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06" # TLS 1.2/1.3 only
  certificate_arn   = var.acm_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }
}
