# Host (Linux/macOS) check for the C++ audio core. Not the iOS build.
CXX      ?= c++
CXXFLAGS ?= -std=c++17 -O2 -Wall -Wextra
INCLUDES  = -Iinclude -Isrc
OUT      ?= /tmp/sk_hello

.PHONY: test clean

test:
	$(CXX) $(CXXFLAGS) $(INCLUDES) src/Engine.cpp tests/hello_render_test.cpp -o $(OUT)
	$(OUT)

clean:
	rm -f $(OUT)
