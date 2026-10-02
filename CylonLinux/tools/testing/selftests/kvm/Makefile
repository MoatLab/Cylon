# SPDX-License-Identifier: GPL-2.0
# This tree has no common KVM test build rules. Keep this target independent.
CFLAGS += -O2 -g -Wall -Wextra -Werror -pthread
LDLIBS += -pthread
TEST_GEN_PROGS := x86_64/dual_mode_first_touch_test
TEST_FILES := x86_64/dual_mode_first_touch_test.md
include ../lib.mk

$(OUTPUT)/x86_64/dual_mode_first_touch_test: x86_64/dual_mode_first_touch_test.c x86_64/dual_mode_first_touch_guest.S
	mkdir -p $(dir $@)
	$(CC) $(CFLAGS) $(KHDR_INCLUDES) $^ $(LDFLAGS) $(LDLIBS) -o $@
