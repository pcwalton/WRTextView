//
//  WRTextLayer.m
//  WRTextView
//
//  Created by Patrick Walton on 5/3/18.
//  Copyright © 2018 Mozilla Foundation. All rights reserved.
//

#import "WRMobileTextLayer.h"
#import "WRMobileTextView.h"
#import "Document.h"
#include "WRMobileGL.h"

@implementation WRMobileTextLayer

- (void)_clearGLErrors {
    while (true) {
        GLuint err = glGetError();
        if (err == GL_NO_ERROR)
            break;
        NSLog(@"warning: OpenGL ES error detected in WebRender: 0x%x", err);
    }
}

- (instancetype)init {
    self = [super init];

    return self;
}

- (BOOL)isOpaque {
    return YES;
}

- (WRMobileTextView *)_textView {
    id<CALayerDelegate> delegate = [self delegate];
    return [delegate isKindOfClass:[WRMobileTextView class]] ? (WRMobileTextView *)delegate : nil;
}

- (void)attachedToWindow {
    if (self->_glContext != nil)
        return;
    
    self->_glContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES3];
    [EAGLContext setCurrentContext:self->_glContext];
    GL(GenFramebuffers(1, &self->_mainFramebuffer));
    GL(BindFramebuffer(GL_FRAMEBUFFER, self->_mainFramebuffer));
    GL(GenRenderbuffers(1, &self->_colorRenderbuffer));
    GL(BindRenderbuffer(GL_RENDERBUFFER, self->_colorRenderbuffer));
    [self->_glContext renderbufferStorage:GL_RENDERBUFFER fromDrawable:self];
    GL(FramebufferRenderbuffer(GL_FRAMEBUFFER,
                               GL_COLOR_ATTACHMENT0,
                               GL_RENDERBUFFER,
                               self->_colorRenderbuffer));
    GLint width, height;
    GL(GetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &width));
    GL(GetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &height));
    GL(GenRenderbuffers(1, &self->_depthStencilRenderbuffer));
    GL(BindRenderbuffer(GL_RENDERBUFFER, self->_depthStencilRenderbuffer));
    GL(RenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH24_STENCIL8, (GLsizei)width, (GLsizei)height));
    GL(FramebufferRenderbuffer(GL_FRAMEBUFFER,
                               GL_DEPTH_STENCIL_ATTACHMENT,
                               GL_RENDERBUFFER,
                               self->_depthStencilRenderbuffer));
    GLuint framebufferStatus = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    NSAssert(framebufferStatus == GL_FRAMEBUFFER_COMPLETE,
             @"Framebuffer incomplete: %x!", framebufferStatus);
    [EAGLContext setCurrentContext:nil];

    UIScreen *screen = [[[self _textView] window] screen];
    self->_displayLink = [screen displayLinkWithTarget:self selector:@selector(redraw)];
    [self->_displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
}

- (void)redraw {
    NSLog(@"redraw");
    
    if (self->_webRenderView == NULL)
        [self _recreateWebRenderView];
    if (self->_webRenderView == NULL)
        return;

    [EAGLContext setCurrentContext:self->_glContext];
    GL(BindFramebuffer(GL_FRAMEBUFFER, self->_mainFramebuffer));

    GLint width, height;
    GL(GetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &width));
    GL(GetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &height));

    wrtv_view_set_scale(self->_webRenderView, 1.0);
    wrtv_view_set_translation(self->_webRenderView, 0.0, 0.0);
    wrtv_view_set_viewport_size(self->_webRenderView, (uint32_t)width, (uint32_t)height);
    
    wrtv_view_repaint(self->_webRenderView);
    [self _clearGLErrors];

    GL(BindRenderbuffer(GL_RENDERBUFFER, self->_colorRenderbuffer));
    [self->_glContext presentRenderbuffer:GL_RENDERBUFFER];
    [EAGLContext setCurrentContext:nil];
}

- (void)_recreateWebRenderView {
    Document *textDocument = [[self _textView] document];
    pilcrow_document_t *document = [textDocument takeDocument];
    if (document == NULL)
        return;
    
    [EAGLContext setCurrentContext:self->_glContext];
    GL(BindFramebuffer(GL_FRAMEBUFFER, self->_mainFramebuffer));

    WRMobileTextView *textView = [self _textView];
    UIScreen *screen = [[textView window] screen];
    CGFloat devicePixelRatio = [screen scale];
    CGSize size = [self bounds].size;
    CGSize backingSize = CGSizeMake(size.width * devicePixelRatio, size.height * devicePixelRatio);

    self->_webRenderView = wrtv_view_new(document,
                                         (uint32_t)ceil(backingSize.width),
                                         (uint32_t)ceil(backingSize.height),
                                         devicePixelRatio,
                                         size.width,
                                         WRTV_API_T_OPENGLES,
                                         getGLProcAddress,
                                         0);
    [self _clearGLErrors];
    
    //[self setDebuggerEnabled:YES];
}

- (void)setDebuggerEnabled:(BOOL)enabled {
    if (self->_webRenderView == NULL)
        return;
    
    wrtv_view_set_debugger_enabled(self->_webRenderView, enabled);
}

@end
