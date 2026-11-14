APP = Survey.app
BIN = $(APP)/Contents/MacOS/Survey

all: $(BIN)

$(BIN): Survey.m Info.plist Makefile
	mkdir -p $(APP)/Contents/MacOS
	cp Info.plist $(APP)/Contents/
	xcrun clang -std=c99 -Wall -Wextra -Werror -fno-objc-arc -fblocks -fno-objc-exceptions -framework Cocoa Survey.m -o $(BIN)

run: all
	open $(APP)

clean:
	rm -rf $(APP)

.PHONY: all run clean
