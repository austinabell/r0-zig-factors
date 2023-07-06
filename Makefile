.PHONY: build run

build:
	cd guest && zig build

run: build
	cargo run