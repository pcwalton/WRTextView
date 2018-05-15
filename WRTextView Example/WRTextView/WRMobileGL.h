//
//  WRMobileGL.h
//  WRTextView
//
//  Created by Patrick Walton on 5/7/18.
//  Copyright © 2018 Mozilla Foundation. All rights reserved.
//

#ifndef WR_MOBILE_GL_H
#define WR_MOBILE_GL_H

#import <OpenGLES/ES3/gl.h>

#ifdef DEBUG
#define GL(x)               ({ \
    gl##x; \
    GLuint _err = glGetError(); \
    NSAssert(_err == GL_NO_ERROR, @"OpenGL error: 0x%x", _err); \
    })
#else
#define GL(x)               gl##x
#endif

static void (*WRGLImpls[300])(void) = { NULL };

static unsigned WRGLNextImpl = 0;

static void (*WRGLCaller)(void) = NULL;

static uint64_t WRGLRetVal = 0;

static void WRGLReportError(GLuint err) {
    NSLog(@"*** GL error: %x", err);
}

#define DEF_WR_DEBUG_SHIM(a, b) \
    static __attribute__((naked)) void WRGLDebugShim##a##b() { \
        asm volatile(                   \
            "popq %%r11;\n"             \
            "movq %%r11,%0;\n"          \
            "movq %1,%%r11;\n"          \
            "callq *%%r11;\n"           \
            "movq %%rax,%2;\n"          \
            "callq _glGetError;\n"      \
            "testl %%eax,%%eax;\n"      \
            "jz 1f;\n"                  \
            "movl %%eax,%%edi;\n"       \
            "callq _WRGLReportError\n"  \
            "1:\n"                      \
            "movq %0,%%r11;\n"          \
            "pushq %%r11;"              \
            "xorq %%r11,%%r11;\n"       \
            "movq %%r11,%0;\n"          \
            "movq %2,%%rax;\n"          \
            "retq;\n"                   \
            :: "m"(WRGLCaller), "m"(WRGLImpls[a*10+b]), "m"(WRGLRetVal), "i"(WRGLReportError) :); \
    }

#define DEF_WR_DEBUG_SHIMS(a)    \
    DEF_WR_DEBUG_SHIM(a, 0)     \
    DEF_WR_DEBUG_SHIM(a, 1)     \
    DEF_WR_DEBUG_SHIM(a, 2)     \
    DEF_WR_DEBUG_SHIM(a, 3)     \
    DEF_WR_DEBUG_SHIM(a, 4)     \
    DEF_WR_DEBUG_SHIM(a, 5)     \
    DEF_WR_DEBUG_SHIM(a, 6)     \
    DEF_WR_DEBUG_SHIM(a, 7)     \
    DEF_WR_DEBUG_SHIM(a, 8)     \
    DEF_WR_DEBUG_SHIM(a, 9)

DEF_WR_DEBUG_SHIMS(0)
DEF_WR_DEBUG_SHIMS(1)
DEF_WR_DEBUG_SHIMS(2)
DEF_WR_DEBUG_SHIMS(3)
DEF_WR_DEBUG_SHIMS(4)
DEF_WR_DEBUG_SHIMS(5)
DEF_WR_DEBUG_SHIMS(6)
DEF_WR_DEBUG_SHIMS(7)
DEF_WR_DEBUG_SHIMS(8)
DEF_WR_DEBUG_SHIMS(9)
DEF_WR_DEBUG_SHIMS(10)
DEF_WR_DEBUG_SHIMS(11)
DEF_WR_DEBUG_SHIMS(12)
DEF_WR_DEBUG_SHIMS(13)
DEF_WR_DEBUG_SHIMS(14)
DEF_WR_DEBUG_SHIMS(15)
DEF_WR_DEBUG_SHIMS(16)
DEF_WR_DEBUG_SHIMS(17)
DEF_WR_DEBUG_SHIMS(18)
DEF_WR_DEBUG_SHIMS(19)
DEF_WR_DEBUG_SHIMS(20)
DEF_WR_DEBUG_SHIMS(21)
DEF_WR_DEBUG_SHIMS(22)
DEF_WR_DEBUG_SHIMS(23)
DEF_WR_DEBUG_SHIMS(24)
DEF_WR_DEBUG_SHIMS(25)
DEF_WR_DEBUG_SHIMS(26)
DEF_WR_DEBUG_SHIMS(27)
DEF_WR_DEBUG_SHIMS(28)
DEF_WR_DEBUG_SHIMS(29)

#define DECL_WR_DEBUG_SHIM(a, b)    WRGLDebugShim##a##b

#define DECL_WR_DEBUG_SHIMS(a)   \
    DECL_WR_DEBUG_SHIM(a, 0),   \
    DECL_WR_DEBUG_SHIM(a, 1),   \
    DECL_WR_DEBUG_SHIM(a, 2),   \
    DECL_WR_DEBUG_SHIM(a, 3),   \
    DECL_WR_DEBUG_SHIM(a, 4),   \
    DECL_WR_DEBUG_SHIM(a, 5),   \
    DECL_WR_DEBUG_SHIM(a, 6),   \
    DECL_WR_DEBUG_SHIM(a, 7),   \
    DECL_WR_DEBUG_SHIM(a, 8),   \
    DECL_WR_DEBUG_SHIM(a, 9)

static void (*WRGLShims[300])(void) = {
    DECL_WR_DEBUG_SHIMS(0),
    DECL_WR_DEBUG_SHIMS(1),
    DECL_WR_DEBUG_SHIMS(2),
    DECL_WR_DEBUG_SHIMS(3),
    DECL_WR_DEBUG_SHIMS(4),
    DECL_WR_DEBUG_SHIMS(5),
    DECL_WR_DEBUG_SHIMS(6),
    DECL_WR_DEBUG_SHIMS(7),
    DECL_WR_DEBUG_SHIMS(8),
    DECL_WR_DEBUG_SHIMS(9),
    DECL_WR_DEBUG_SHIMS(10),
    DECL_WR_DEBUG_SHIMS(11),
    DECL_WR_DEBUG_SHIMS(12),
    DECL_WR_DEBUG_SHIMS(13),
    DECL_WR_DEBUG_SHIMS(14),
    DECL_WR_DEBUG_SHIMS(15),
    DECL_WR_DEBUG_SHIMS(16),
    DECL_WR_DEBUG_SHIMS(17),
    DECL_WR_DEBUG_SHIMS(18),
    DECL_WR_DEBUG_SHIMS(19),
    DECL_WR_DEBUG_SHIMS(20),
    DECL_WR_DEBUG_SHIMS(21),
    DECL_WR_DEBUG_SHIMS(22),
    DECL_WR_DEBUG_SHIMS(23),
    DECL_WR_DEBUG_SHIMS(24),
    DECL_WR_DEBUG_SHIMS(25),
    DECL_WR_DEBUG_SHIMS(26),
    DECL_WR_DEBUG_SHIMS(27),
    DECL_WR_DEBUG_SHIMS(28),
    DECL_WR_DEBUG_SHIMS(29),
};

static const void *getGLProcAddress(const char *symbolName) {
    NSCAssert(WRGLCaller == 0, @"Recursive GL call!");
    CFBundleRef bundle = CFBundleGetBundleWithIdentifier(CFSTR("com.apple.opengles"));
    NSString *symbolString = [NSString stringWithUTF8String:symbolName];
    const void *glFunc = CFBundleGetFunctionPointerForName(bundle,
                                                           (__bridge CFStringRef)symbolString);
    if (glFunc == NULL)
        return NULL;
    NSCAssert(WRGLNextImpl < sizeof(WRGLImpls) / sizeof(WRGLImpls[0]), @"Too many GL functions!");
    WRGLImpls[WRGLNextImpl] = glFunc;
    const void *shim = WRGLShims[WRGLNextImpl];
    WRGLNextImpl++;
    return shim;
}

#endif /* WR_MOBILE_GL_H */
