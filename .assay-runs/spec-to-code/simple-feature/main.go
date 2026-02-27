package main

import (
	"fmt"
	"os"
)

func add(a, b int) int {
	return a + b
}

func main() {
	if len(os.Args) != 3 {
		fmt.Println("Usage: go run main.go <num1> <num2>")
		os.Exit(1)
	}

	num1, _ := strconv.Atoi(os.Args[1])
	num2, _ := strconv.Atoi(os.Args[2])
	result := add(num1, num2)
	fmt.Println("Result:", result)
}
