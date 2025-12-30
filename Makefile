include config.mk

.PHONY: all clean compile deploy build run verify-deps

all: verify-deps compile deploy build run

verify-deps:
	@which sshpass > /dev/null || (echo "Error: sshpass not found. Install it first."; exit 1)
	@test -f $(SOURCE) || (echo "Error: Source file $(SOURCE) not found."; exit 1)

compile:
	@echo "--- Compiling $(SOURCE) locally ---"
	chmod +x $(MORPH_COMPILER)
	$(MORPH_COMPILER) $(SOURCE) > $(OUTPUT_NAME).asm
	@echo "Generated $(OUTPUT_NAME).asm"

deploy:
	@echo "--- Deploying to VPS ---"
	sshpass -p '$(VPS_PASS)' ssh -o StrictHostKeyChecking=no $(VPS_USER)@$(VPS_HOST) "mkdir -p $(VPS_DIR)"
	sshpass -p '$(VPS_PASS)' scp -o StrictHostKeyChecking=no $(OUTPUT_NAME).asm $(VPS_USER)@$(VPS_HOST):$(VPS_DIR)/

build:
	@echo "--- Building on VPS (NASM + LD) ---"
	sshpass -p '$(VPS_PASS)' ssh -o StrictHostKeyChecking=no $(VPS_USER)@$(VPS_HOST) \
		"cd $(VPS_DIR) && nasm -f elf64 $(OUTPUT_NAME).asm -o $(OUTPUT_NAME).o && ld $(OUTPUT_NAME).o -o $(OUTPUT_NAME)"

run:
	@echo "--- Running on VPS ---"
	@sshpass -p '$(VPS_PASS)' ssh -o StrictHostKeyChecking=no $(VPS_USER)@$(VPS_HOST) \
		"cd $(VPS_DIR) && ./$(OUTPUT_NAME)"

clean:
	rm -f $(OUTPUT_NAME).asm
	sshpass -p '$(VPS_PASS)' ssh -o StrictHostKeyChecking=no $(VPS_USER)@$(VPS_HOST) \
		"rm -f $(VPS_DIR)/$(OUTPUT_NAME).asm $(VPS_DIR)/$(OUTPUT_NAME).o $(VPS_DIR)/$(OUTPUT_NAME)"
