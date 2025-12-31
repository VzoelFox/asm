include config.mk

.PHONY: all clean compile-prog deploy run-prog verify-deps

all: verify-deps compile-prog deploy run-prog

verify-deps:
	@which sshpass > /dev/null || (echo "Error: sshpass not found. Install it first."; exit 1)
	@test -f $(SOURCE) || (echo "Error: Source file $(SOURCE) not found."; exit 1)

compile-prog:
	@echo "--- Compiling $(SOURCE) to Assembly ---"
	chmod +x $(MORPH_COMPILER)
	$(MORPH_COMPILER) $(SOURCE) > $(OUTPUT_NAME).asm
	@echo "Generated $(OUTPUT_NAME).asm"

deploy:
	@echo "--- Deploying to VPS ---"
	sshpass -p '$(VPS_PASS)' ssh -o StrictHostKeyChecking=no $(VPS_USER)@$(VPS_HOST) "mkdir -p $(VPS_DIR)"
	# Upload Program Assembly
	sshpass -p '$(VPS_PASS)' scp -o StrictHostKeyChecking=no $(OUTPUT_NAME).asm $(VPS_USER)@$(VPS_HOST):$(VPS_DIR)/

run-prog:
	@echo "--- Assembling and Running on VPS ---"
	@sshpass -p '$(VPS_PASS)' ssh -o StrictHostKeyChecking=no $(VPS_USER)@$(VPS_HOST) \
		"cd $(VPS_DIR) && nasm -f elf64 $(OUTPUT_NAME).asm -o $(OUTPUT_NAME).o && ld $(OUTPUT_NAME).o -o $(OUTPUT_NAME) && ./$(OUTPUT_NAME)"

clean:
	rm -f $(OUTPUT_NAME).asm
	sshpass -p '$(VPS_PASS)' ssh -o StrictHostKeyChecking=no $(VPS_USER)@$(VPS_HOST) \
		"rm -f $(VPS_DIR)/*.asm $(VPS_DIR)/*.o $(VPS_DIR)/$(OUTPUT_NAME)"
