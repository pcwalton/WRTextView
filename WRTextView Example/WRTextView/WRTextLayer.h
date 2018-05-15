//
//  WRTextLayer.h
//  WRTextView Example
//
//  Created by Patrick Walton on 4/11/18.
//  Copyright © 2018 Mozilla Foundation. All rights reserved.
//

#import <TargetConditionals.h>

#if !TARGET_OS_IPHONE && !TARGET_OS_SIMULATOR && !TARGET_OS_EMBEDDED
#import <Cocoa/Cocoa.h>
#else
#import <QuartzCore/QuartzCore.h>
#import <OpenGLES/ES3/gl.h>
#import <UIKit/UIKit.h>
#endif

#include <pilcrow.h>
#include <wr-text-view.h>

@class WRTextView;

#if !TARGET_OS_IPHONE && !TARGET_OS_SIMULATOR && !TARGET_OS_EMBEDDED
@interface WRTextLayer : CAOpenGLLayer {
#else
@interface WRTextLayer : CAEAGLLayer {
    EAGLContext *_glContext;
    CADisplayLink *_displayLink;
    GLuint _mainFramebuffer;
    GLuint _colorRenderbuffer;
    GLuint _depthStencilRenderbuffer;
    BOOL _isAsynchronous;
    BOOL _isDirty;
#endif
    wrtv_view_t *_webRenderView;
}

- (WRTextView *)_textView;
- (void)reloadText;
- (void)setDebuggerEnabled:(BOOL)enabled;
- (void)reshape;
- (NSString *)allText;
- (NSString *)selectedText;
- (void)selectAll;
- (BOOL)isReady;
- (void)setDirty;
#if !TARGET_OS_IPHONE && !TARGET_OS_SIMULATOR && !TARGET_OS_EMBEDDED
- (void)setImage:(NSImage *)image forID:(uint32_t)imageID;
- (void)mouseDown:(NSEvent *)event;
- (void)mouseDragged:(NSEvent *)event;
- (void)mouseUp:(NSEvent *)event;
- (void)mouseMoved:(NSEvent *)event;
#else
- (void)setImage:(UIImage *)image forID:(uint32_t)imageID;
- (void)attachedToWindow;
- (void)setAsynchronous:(BOOL)isAsynchronous;
#endif

@end
