// V's thirdparty object builder looks for .c/.cpp/.S sources for #flag object
// inputs. Keep the implementation in webview_bridge.cc, and expose this .cpp
// wrapper for compilers that build cached thirdparty objects themselves.
#include "webview_bridge.cc"
