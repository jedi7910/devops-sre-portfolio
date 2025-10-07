resource "aws_security_group" "main" {
    name_prefix = "${var.environment}-web"
    description = "Security group for web servers"
    vpc_id      = var.vpc_id

    dynamic "ingress" {
        for_each = var.ingress_rules
        content {
            from_port   = ingress.value.from_port
            to_port     = ingress.value.to_port
            protocol    = ingress.value.protocol
            cidr_blocks = ingress.value.cidr_blocks
            description = ingress.value.description
        }
    }

    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
        description = "Allow all outbound traffic"
    }

    tags = merge(
        var.tags,
        {
            Name = "${var.environment}-web-sg"
        }
    )
    
    lifecycle {
        create_before_destroy = true
    }
}