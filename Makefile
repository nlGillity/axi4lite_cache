# Verilator build and run for the AXI4-Lite cache testbench
VERILATOR ?= verilator
TOP       := axi4lite_cache_tb
BUILD_DIR := build
OBJ_DIR   := $(BUILD_DIR)/obj_dir
BIN       := $(OBJ_DIR)/V$(TOP)
INCLUDES := \
	-Isrc/common_cells/include \
	-Isrc/axi4lite_cache

# `OKAY is used as the AXI OKAY response code (2'b00).
DEFINES := -DOKAY=0 -DDEBUG_ON
VERILATOR_FLAGS := \
	--binary \
	--timing \
	--trace \
	-Wall \
	-Wno-fatal \
	-Wno-EOFNEWLINE \
	-Wno-TIMESCALEMOD \
	-Wno-PINCONNECTEMPTY \
	-Wno-GENUNNAMED \
	-Wno-UNUSEDPARAM \
	-Wno-UNUSEDSIGNAL \
	-Wno-WIDTHTRUNC \
	--top-module $(TOP) \
	--Mdir $(OBJ_DIR) \
	$(INCLUDES) \
	$(DEFINES)

RTL := \
	src/common_cells/src/cc_pkg.sv \
	src/common_cells/src/cc_fifo.sv \
	src/common_cells/src/cc_stream_fifo.sv \
	src/common_cells/src/cc_onehot_to_bin.sv \
	src/common_cells/src/cc_credit_counter.sv \
	src/memory/memory.sv \
	src/memory/reg_memory.sv \
	src/buffer/buffer.sv \
	src/arbiter/arbiter.sv \
	src/comparator/comparator.sv \
	src/prg/prg.sv \
	src/evicting_block/evicting_block.sv \
	src/tag_memory/tag_memory.sv \
	src/data_memory/data_memory.sv \
	src/axi4lite_cache/stages/fetch/fetch_stage.sv \
	src/axi4lite_cache/stages/lookup/lookup_stage.sv \
	src/axi4lite_cache/axi4lite_cache.sv \
	src/axi4lite_cache/axi4lite_cache_tb.sv

LINT_RTL := $(filter-out src/common_cells/%,$(RTL))

.PHONY: all compile run clean lint
all: run
compile:
	@mkdir -p $(BUILD_DIR)
	$(VERILATOR) $(VERILATOR_FLAGS) $(RTL)
run: compile
	$(BIN)
lint:
	$(VERILATOR) --lint-only --timing -Wall -Wno-fatal -Wno-EOFNEWLINE \
		--top-module $(TOP) $(INCLUDES) $(DEFINES) $(LINT_RTL)
clean:
	rm -rf $(BUILD_DIR)
