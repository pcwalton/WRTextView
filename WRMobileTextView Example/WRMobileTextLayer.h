//
//  WRTextLayer.h
//  WRTextView
//
//  Created by Patrick Walton on 5/3/18.
//  Copyright © 2018 Mozilla Foundation. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import <CoreText/CoreText.h>
#include <OpenGLES/ES3/gl.h>
#include <pilcrow.h>
#include <wr-text-view.h>

@interface WRMobileTextLayer : CAEAGLLayer {
    EAGLContext *_glContext;
    CADisplayLink *_displayLink;
    GLuint _mainFramebuffer;
    GLuint _colorRenderbuffer;
    GLuint _depthStencilRenderbuffer;
    wrtv_view_t *_webRenderView;
}

- (void)attachedToWindow;

@end
