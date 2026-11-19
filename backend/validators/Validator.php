<?php
/**
 * Request validator - basic input validation
 */
final class Validator
{
    private array $errors = [];
    private array $data;

    public function __construct(array $data)
    {
        $this->data = $data;
    }

    public function required(string $field): self
    {
        if (!isset($this->data[$field]) || $this->data[$field] === '' || $this->data[$field] === null) {
            $this->errors[$field][] = "$field is required.";
        }
        return $this;
    }

    public function email(string $field): self
    {
        if (!empty($this->data[$field]) && !validate_email($this->data[$field])) {
            $this->errors[$field][] = "$field must be a valid email.";
        }
        return $this;
    }

    public function min(string $field, int $len): self
    {
        if (!empty($this->data[$field]) && mb_strlen((string)$this->data[$field]) < $len) {
            $this->errors[$field][] = "$field must be at least $len characters.";
        }
        return $this;
    }

    public function max(string $field, int $len): self
    {
        if (!empty($this->data[$field]) && mb_strlen((string)$this->data[$field]) > $len) {
            $this->errors[$field][] = "$field must be at most $len characters.";
        }
        return $this;
    }

    public function in(string $field, array $allowed): self
    {
        if (!empty($this->data[$field]) && !in_array($this->data[$field], $allowed, true)) {
            $this->errors[$field][] = "$field must be one of: " . implode(', ', $allowed);
        }
        return $this;
    }

    public function sameAs(string $field, string $other): self
    {
        if (($this->data[$field] ?? null) !== ($this->data[$other] ?? null)) {
            $this->errors[$field][] = "$field must match $other.";
        }
        return $this;
    }

    public function fails(): bool
    {
        return !empty($this->errors);
    }

    public function errors(): array
    {
        return $this->errors;
    }

    public function validated(): array
    {
        return $this->data;
    }
}
