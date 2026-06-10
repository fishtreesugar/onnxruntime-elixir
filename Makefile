PRIV_DIR := $(MIX_APP_PATH)/priv
NIF_NAME := onnxruntime
NIF_PATH := $(PRIV_DIR)/$(NIF_NAME).so
C_SRC := $(shell pwd)/c_src
VENDOR_DIR := $(shell pwd)/vendor/onnxruntime
ONNXRUNTIME_VERSION ?= 1.26.0
ORT_TARGET ?= $(if $(CC_PRECOMPILER_CURRENT_TARGET),$(CC_PRECOMPILER_CURRENT_TARGET),$(shell uname -s | tr '[:upper:]' '[:lower:]')-$(shell uname -m))

CPPFLAGS += -shared -fPIC -fvisibility=hidden -std=c++17 -Wall -Wextra
CPPFLAGS += -I$(ERTS_INCLUDE_DIR) -I$(FINE_INCLUDE_DIR)

ifdef DEBUG
  CPPFLAGS += -g
else
  CPPFLAGS += -O3
endif

ifndef TARGET_ABI
  TARGET_ABI := $(shell uname -s | tr '[:upper:]' '[:lower:]')
endif

ifeq ($(TARGET_ABI),darwin)
  CPPFLAGS += -undefined dynamic_lookup -flat_namespace
  LDFLAGS += -Wl,-rpath,@loader_path
  ORT_LIB_PATTERN := libonnxruntime*.dylib*
else ifeq ($(OS),Windows_NT)
  NIF_PATH := $(PRIV_DIR)/$(NIF_NAME).dll
  ORT_LIB_PATTERN := onnxruntime.dll
else
  LDFLAGS += -Wl,-rpath,'$$ORIGIN'
  ORT_LIB_PATTERN := libonnxruntime*.so*
endif

ifeq ($(strip $(ORT_INCLUDE_DIR)),)
  ORT_ROOT := $(VENDOR_DIR)/$(ONNXRUNTIME_VERSION)/$(ORT_TARGET)
  ORT_INCLUDE_DIR := $(ORT_ROOT)/include
  ORT_LIB_DIR := $(ORT_ROOT)/lib
endif

CPPFLAGS += -I$(ORT_INCLUDE_DIR)
LDFLAGS += -L$(ORT_LIB_DIR) -lonnxruntime

SOURCES := $(wildcard $(C_SRC)/*.cpp)

.PHONY: all clean fetch_onnxruntime

all: fetch_onnxruntime $(NIF_PATH)
	@ echo > /dev/null

fetch_onnxruntime:
	@if [ ! -f "$(ORT_INCLUDE_DIR)/onnxruntime_cxx_api.h" ]; then \
		scripts/fetch_onnxruntime.sh "$(ONNXRUNTIME_VERSION)" "$(VENDOR_DIR)" "$(ORT_TARGET)"; \
	fi

$(NIF_PATH): $(SOURCES)
	@ mkdir -p $(PRIV_DIR)
	$(CXX) $(CPPFLAGS) $(SOURCES) $(LDFLAGS) -o $(NIF_PATH)
	@ for lib in $(ORT_LIB_DIR)/$(ORT_LIB_PATTERN); do \
		if [ -f "$$lib" ]; then cp "$$lib" $(PRIV_DIR)/; fi; \
	done

clean:
	$(RM) -r $(PRIV_DIR)/*.so $(PRIV_DIR)/*.dll $(PRIV_DIR)/*.dylib $(PRIV_DIR)/libonnxruntime*
