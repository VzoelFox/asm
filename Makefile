include config.mk

.PHONY: all clean compile-vm compile-prog deploy build-vm run-vm verify-deps

all: verify-deps compile-vm compile-prog deploy build-vm run-vm

verify-deps:
	@which sshpass > /dev/null || (echo "Error: sshpass not found. Install it first."; exit 1)
	@test -f $(SOURCE) || (echo "Error: Source file $(SOURCE) not found."; exit 1)

compile-vm:
	@echo "--- Preparing VM Source ---"
	# Nothing to compile locally for VM, just ensuring file exists
	@test -f bootstrap/vm.asm || (echo "Error: bootstrap/vm.asm missing"; exit 1)

compile-prog:
	@echo "--- Compiling $(SOURCE) to Bytecode ---"
	chmod +x $(MORPH_COMPILER)
	$(MORPH_COMPILER) $(SOURCE) > $(OUTPUT_NAME).morph
	@echo "Generated $(OUTPUT_NAME).morph"

deploy:
	@echo "--- Deploying to VPS ---"
	sshpass -p '$(VPS_PASS)' ssh -o StrictHostKeyChecking=no $(VPS_USER)@$(VPS_HOST) "mkdir -p $(VPS_DIR)"
	# Upload VM Source
	sshpass -p '$(VPS_PASS)' scp -o StrictHostKeyChecking=no bootstrap/vm.asm $(VPS_USER)@$(VPS_HOST):$(VPS_DIR)/
	# Upload Program Bytecode
	sshpass -p '$(VPS_PASS)' scp -o StrictHostKeyChecking=no $(OUTPUT_NAME).morph $(VPS_USER)@$(VPS_HOST):$(VPS_DIR)/

build-vm:
	@echo "--- Building VM on VPS ---"
	sshpass -p '$(VPS_PASS)' ssh -o StrictHostKeyChecking=no $(VPS_USER)@$(VPS_HOST) \
		"cd $(VPS_DIR) && nasm -f elf64 vm.asm -o vm.o && ld vm.o -o vm"

run-vm:
	@echo "--- Running Program on VM ---"
	@sshpass -p '$(VPS_PASS)' ssh -o StrictHostKeyChecking=no $(VPS_USER)@$(VPS_HOST) \
		"cd $(VPS_DIR) && ./vm $(OUTPUT_NAME).morph"

clean:
	rm -f $(OUTPUT_NAME).morph
	sshpass -p '$(VPS_PASS)' ssh -o StrictHostKeyChecking=no $(VPS_USER)@$(VPS_HOST) \
		"rm -f $(VPS_DIR)/vm* $(VPS_DIR)/*.morph"
