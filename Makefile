BUILD_DIR = build/$(MCU)

.PHONY: build
build:
	mkdir -p $(BUILD_DIR)
	cmake -E chdir $(BUILD_DIR) cmake -DMCU_NAME=$(MCU) ../..
	cmake --build $(BUILD_DIR)

.PHONY: clean
clean:
	rm -r build

.PHONY: install
install:
	cmake --build $(BUILD_DIR) --target install
