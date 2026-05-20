/* ========================================================================
	File		- DBGWIND.HXX
	Description - Public interface for the debug test window facility.
				  In _DEBUG builds on Windows this exposes a modal pop-up
				  window that lets developers trigger in-game test scenarios
				  (grant inventory items, force assassinations, show
				  end-of-adventure screens) without modifying saved state.
				  In non-debug or non-Windows builds all declarations reduce
				  to a no-op stub with the same signature.
	======================================================================== */

#ifndef _DBGWIND_HXX
#define _DBGWIND_HXX

#if !defined(_TYPEDEFS_H)
#include "typedefs.h"
#endif

/* ========================================================================
	Function	- DebugShowTestWindow
	Description - Opens the debug test window (Windows _DEBUG builds) and
				  dispatches the action chosen by the developer.  Supported
				  actions are:
				    - Grant a named inventory item to the whole adventure party.
				    - Trigger a random-unit assassination event (realm mode).
				    - Display the end-of-adventure quest-item victory screen.
				  In non-debug or non-Windows builds this is a no-op stub.
	Parameters	- Two LONG parameters matching the standard debug-key-handler
				  signature (key code and modifier flags).  Both are unused.
	Returns		- (void)
	======================================================================== */
void DebugShowTestWindow(LONG, LONG);

#endif
