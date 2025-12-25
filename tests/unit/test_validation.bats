#!/usr/bin/env bats
# Unit tests for validation functions in cloud-init.yml

# Load test helpers
load '../helpers/setup'

setup() {
  # Source the validation functions
  source_cloud_init_functions
}

# =============================================================================
# Domain Validation Tests
# =============================================================================

@test "validate_domain: accepts valid single-level domain" {
  run validate_domain "example.com"
  [ "$status" -eq 0 ]
}

@test "validate_domain: accepts valid multi-level domain" {
  run validate_domain "vpn.prod.example.com"
  [ "$status" -eq 0 ]
}

@test "validate_domain: accepts domain with numbers" {
  run validate_domain "vpn1.example2.com"
  [ "$status" -eq 0 ]
}

@test "validate_domain: accepts domain with hyphens" {
  run validate_domain "my-vpn.example-site.com"
  [ "$status" -eq 0 ]
}

@test "validate_domain: rejects domain with consecutive hyphens" {
  run validate_domain "exam--ple.com"
  [ "$status" -eq 1 ]
}

@test "validate_domain: rejects domain starting with hyphen" {
  run validate_domain "-example.com"
  [ "$status" -eq 1 ]
}

@test "validate_domain: rejects domain ending with hyphen" {
  run validate_domain "example-.com"
  [ "$status" -eq 1 ]
}

@test "validate_domain: rejects TLD without domain" {
  run validate_domain ".com"
  [ "$status" -eq 1 ]
}

@test "validate_domain: rejects domain without TLD" {
  run validate_domain "example"
  [ "$status" -eq 1 ]
}

@test "validate_domain: rejects empty string" {
  run validate_domain ""
  [ "$status" -eq 1 ]
}

@test "validate_domain: rejects domain with spaces" {
  run validate_domain "example .com"
  [ "$status" -eq 1 ]
}

@test "validate_domain: rejects domain with underscores" {
  run validate_domain "example_site.com"
  [ "$status" -eq 1 ]
}

# =============================================================================
# Email Validation Tests
# =============================================================================

@test "validate_email: accepts standard email" {
  run validate_email "user@example.com"
  [ "$status" -eq 0 ]
}

@test "validate_email: accepts email with plus addressing" {
  run validate_email "user+tag@example.com"
  [ "$status" -eq 0 ]
}

@test "validate_email: accepts email with subdomain" {
  run validate_email "user@mail.example.com"
  [ "$status" -eq 0 ]
}

@test "validate_email: accepts email with dots in local part" {
  run validate_email "first.last@example.com"
  [ "$status" -eq 0 ]
}

@test "validate_email: accepts email with numbers" {
  run validate_email "user123@example456.com"
  [ "$status" -eq 0 ]
}

@test "validate_email: KNOWN BUG - accepts double @ (should fail)" {
  # This is a documented bug in the simple regex
  # The regex ^[^@]+@[^@]+\.[^@]+$ is too permissive
  run validate_email "user@@example.com"
  # Current behavior: passes (BUG)
  # Expected behavior: should fail
  [ "$status" -eq 0 ]
  # TODO: Fix regex to properly reject this
}

@test "validate_email: rejects email without @" {
  run validate_email "userexample.com"
  [ "$status" -eq 1 ]
}

@test "validate_email: rejects email without domain" {
  run validate_email "user@"
  [ "$status" -eq 1 ]
}

@test "validate_email: rejects email without local part" {
  run validate_email "@example.com"
  [ "$status" -eq 1 ]
}

@test "validate_email: rejects email without TLD" {
  run validate_email "user@example"
  [ "$status" -eq 1 ]
}

@test "validate_email: rejects empty string" {
  run validate_email ""
  [ "$status" -eq 1 ]
}

@test "validate_email: rejects email with spaces" {
  run validate_email "user @example.com"
  [ "$status" -eq 1 ]
}

# =============================================================================
# UUID/Tenant ID Validation Tests
# =============================================================================

@test "validate_uuid: accepts valid GUID format" {
  run validate_uuid "550e8400-e29b-41d4-a716-446655440000"
  [ "$status" -eq 0 ]
}

@test "validate_uuid: accepts valid GUID with uppercase" {
  run validate_uuid "550E8400-E29B-41D4-A716-446655440000"
  [ "$status" -eq 0 ]
}

@test "validate_uuid: accepts valid GUID with mixed case" {
  run validate_uuid "550e8400-E29b-41D4-a716-446655440000"
  [ "$status" -eq 0 ]
}

@test "validate_uuid: accepts onmicrosoft.com tenant" {
  run validate_uuid "contoso.onmicrosoft.com"
  [ "$status" -eq 0 ]
}

@test "validate_uuid: accepts onmicrosoft.com with hyphens" {
  run validate_uuid "my-company.onmicrosoft.com"
  [ "$status" -eq 0 ]
}

@test "validate_uuid: accepts onmicrosoft.com with numbers" {
  run validate_uuid "company123.onmicrosoft.com"
  [ "$status" -eq 0 ]
}

@test "validate_uuid: rejects invalid GUID (wrong segment lengths)" {
  run validate_uuid "550e8400-e29b-41d4-a716-44665544000"  # Missing digit
  [ "$status" -eq 1 ]
}

@test "validate_uuid: rejects invalid GUID (extra segment)" {
  run validate_uuid "550e8400-e29b-41d4-a716-446655440000-extra"
  [ "$status" -eq 1 ]
}

@test "validate_uuid: rejects GUID with invalid characters" {
  run validate_uuid "550e8400-e29b-41d4-a716-44665544000g"
  [ "$status" -eq 1 ]
}

@test "validate_uuid: rejects invalid onmicrosoft.com format" {
  run validate_uuid "invalid-.onmicrosoft.com"
  [ "$status" -eq 1 ]
}

@test "validate_uuid: rejects onmicrosoft.com starting with hyphen" {
  run validate_uuid "-company.onmicrosoft.com"
  [ "$status" -eq 1 ]
}

@test "validate_uuid: rejects plain string" {
  run validate_uuid "not-a-valid-uuid"
  [ "$status" -eq 1 ]
}

@test "validate_uuid: rejects empty string" {
  run validate_uuid ""
  [ "$status" -eq 1 ]
}

@test "validate_uuid: rejects GUID without hyphens" {
  run validate_uuid "550e8400e29b41d4a716446655440000"
  [ "$status" -eq 1 ]
}
