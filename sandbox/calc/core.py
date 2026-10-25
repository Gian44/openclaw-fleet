"""Core arithmetic. Deliberately incomplete: the fleet's tasks fill the gaps."""


def add(a: float, b: float) -> float:
    return a + b


def subtract(a: float, b: float) -> float:
    return a - b


def multiply(a: float, b: float) -> float:
    return a * b


def divide(a: float, b: float) -> float:
    # BUG: no zero check (fleet task #2)
    return a / b


def mean(values: list[float]) -> float:
    # BUG: empty list crashes (fleet task #3)
    return sum(values) / len(values)
