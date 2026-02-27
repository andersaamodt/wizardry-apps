package main

import (
	"testing"
)

func TestAdd(t *testing.T) {
	testCases := []struct {
		name     string
		num1     int
		num2     int
		expected int
	}{
		{"Positive numbers", 3, 5, 8},
		{"Zero and positive number", 0, 7, 7},
		{"Negative numbers", -2, -4, -6},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			result := add(tc.num1, tc.num2)
			if result != tc.expected {
				t.Errorf("add(%d, %d) = %d; want %d", tc.num1, tc.num2, result, tc.expected)
			}
		})
	}
}
