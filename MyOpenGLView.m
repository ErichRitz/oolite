/*
 *
 *  Oolite
 *
 *  Created by Giles Williams on Sat Apr 03 2004.
 *  Copyright (c) 2004 for aegidian.org. All rights reserved.
 *

Copyright (c) 2004, Giles C Williams
All rights reserved.

This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike License.
To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-sa/2.0/
or send a letter to Creative Commons, 559 Nathan Abbott Way, Stanford, California 94305, USA.

You are free:

�	to copy, distribute, display, and perform the work
�	to make derivative works

Under the following conditions:

�	Attribution. You must give the original author credit.

�	Noncommercial. You may not use this work for commercial purposes.

�	Share Alike. If you alter, transform, or build upon this work,
you may distribute the resulting work only under a license identical to this one.

For any reuse or distribution, you must make clear to others the license terms of this work.

Any of these conditions can be waived if you get permission from the copyright holder.

Your fair use and other rights are in no way affected by the above.

*/
//#import <OpenGL/glext.h>

#import "MyOpenGLView.h"

#import "GameController.h"
//#import "AppDelegate.h"
#import "Universe.h"
#import "TextureStore.h"
#import "Entity.h"
#import "PlanetEntity.h"
#import "OpenGLSprite.h"
#import "ResourceManager.h"

@interface MyOpenGLView(Internal)

- (void) pollControls;

@end


@implementation MyOpenGLView

- (id) initWithFrame:(NSRect)frameRect
{
	self = [super init];

	NSLog(@"initialising SDL");
	if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO) < 0)
	{
		NSLog(@"Unable to init SDL: %s\n", SDL_GetError());
		[self dealloc];
		return nil;
    }
	else if (Mix_OpenAudio(22050, AUDIO_S16LSB, 2, 2048) < 0)
	{
		NSLog(@"Mix_OpenAudio: %s\n", Mix_GetError());
		[self dealloc];
		return nil;
	}

	Mix_AllocateChannels(MAX_CHANNELS);

	SDL_GL_SetAttribute(SDL_GL_RED_SIZE, 5);
	SDL_GL_SetAttribute(SDL_GL_GREEN_SIZE, 5);
	SDL_GL_SetAttribute(SDL_GL_BLUE_SIZE, 5);
	SDL_GL_SetAttribute(SDL_GL_DEPTH_SIZE, 16);
	SDL_GL_SetAttribute(SDL_GL_DOUBLEBUFFER, 1);

	screenSizes[0] = NSMakeSize(640, 480);
	screenSizes[1] = NSMakeSize(800, 600);
	screenSizes[2] = NSMakeSize(1024, 768);
	currentSize = 1;
	fullScreen = NO;

	surface = SDL_SetVideoMode((int)frameRect.size.width, (int)frameRect.size.height, 32, SDL_HWSURFACE | SDL_OPENGL);
	bounds.size.width = surface->w;
	bounds.size.height = surface->h;

	virtualJoystickPosition = NSMakePoint(0.0,0.0);
	
	typedString = [[NSMutableString alloc] initWithString:@""];
	allowingStringInput = NO;
	isAlphabetKeyDown = NO;

	m_glContextInitialized = NO;

    return self;
}

- (void) dealloc
{
	if (typedString)
		[typedString release];

	if (surface != 0)
	{
		SDL_FreeSurface(surface);
		surface = 0;
	}

	SDL_Quit();

	[super dealloc];
}

- (void) allowStringInput: (BOOL) value
{
	allowingStringInput = value;
}

-(BOOL) allowingStringInput
{
	return allowingStringInput;
}

- (NSString *) typedString
{
	return typedString;
}

- (void) resetTypedString
{
	[typedString setString:@""];
}

- (void) setTypedString:(NSString*) value
{
//	NSLog(@"DEBUG setTypedString:%@",value);
	[typedString setString:value];
}

- (NSRect) bounds
{
	return bounds;
}

- (NSSize) viewSize
{
	return viewSize;
}

- (GLfloat) display_z
{
	return display_z;
}


- (GameController *) gameController
{
	return gameController;
}

- (void) setGameController:(GameController *) controller
{
	gameController = controller;
}

- (void) display
{
	[self drawRect: NSMakeRect(0, 0, viewSize.width, viewSize.height)];
	[self pollControls];
}

- (void) drawRect:(NSRect)rect
{
	if ((viewSize.width != surface->w)||(viewSize.height != surface->h)) // resized
	{
		m_glContextInitialized = NO;
		viewSize.width = surface->w;
		viewSize.height = surface->h;
		//NSLog(@"DEBUG resized to %.0f x %.0f", viewSize.width, viewSize.height);
	}

    if (m_glContextInitialized == NO)
	{
		NSLog(@"drawRect calling initialiseGLWithSize");
		[self initialiseGLWithSize:viewSize];
	}

	if (surface == 0)
		return;

	// do all the drawing!
	//
	if ([gameController universe])
		[[gameController universe] drawFromEntity:0];
	else
	{
		// not set up yet, draw a black screen
		NSLog(@"no universe, clearning surface");
		glClearColor( 0.0, 0.0, 0.0, 0.0);
		glClear( GL_COLOR_BUFFER_BIT);
	}

	SDL_GL_SwapBuffers();
}

- (void) initialiseGLWithSize:(NSSize) v_size
{
	int videoModeFlags;
	GLfloat	sun_ambient[] =	{0.1, 0.1, 0.1, 1.0};
	GLfloat	sun_diffuse[] =	{1.0, 1.0, 1.0, 1.0};
	GLfloat	sun_specular[] = 	{1.0, 1.0, 1.0, 1.0};
	GLfloat	sun_center_position[] = {4000000.0, 0.0, 0.0, 1.0};

	viewSize = v_size;
	if (viewSize.width/viewSize.height > 4.0/3.0)
		display_z = 480.0 * viewSize.width/viewSize.height;
	else
		display_z = 640.0;

//	NSLog(@">>>>> display_z = %.1f", display_z);

	float	ratio = 0.5;
	float   aspect = viewSize.height/viewSize.width;

	if (surface != 0)
		SDL_FreeSurface(surface);

	NSLog(@"Creating a new surface of %d x %d", (int)v_size.width, (int)v_size.height);
	videoModeFlags = SDL_HWSURFACE | SDL_OPENGL;
	if (fullScreen == YES)
		videoModeFlags |= SDL_FULLSCREEN;

	surface = SDL_SetVideoMode((int)v_size.width, (int)v_size.height, 32, videoModeFlags);

	glShadeModel(GL_FLAT);
	glClearColor(0.0, 0.0, 0.0, 0.0);
    glClear(GL_COLOR_BUFFER_BIT);
    SDL_GL_SwapBuffers();
	
	glClearDepth(MAX_CLEAR_DEPTH);
	glViewport( 0, 0, viewSize.width, viewSize.height);
	
	squareX = 0.0;
	glMatrixMode(GL_PROJECTION);
	glLoadIdentity();	// reset matrix
	glFrustum( -ratio, ratio, -aspect*ratio, aspect*ratio, 1.0, MAX_CLEAR_DEPTH);	// set projection matrix

	glMatrixMode( GL_MODELVIEW);

	glEnable( GL_DEPTH_TEST);		// depth buffer
	glDepthFunc( GL_LESS);			// depth buffer

	glFrontFace( GL_CCW);			// face culling - front faces are AntiClockwise!
	glCullFace( GL_BACK);			// face culling
	glEnable( GL_CULL_FACE);		// face culling

	glEnable( GL_BLEND);								// alpha blending
	glBlendFunc( GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);	// alpha blending

	if ([gameController universe])
	{
		Entity* the_sun = [[gameController universe] sun];
		Vector sun_pos = (the_sun)? the_sun->position : make_vector(0,0,0);
		sun_center_position[0] = sun_pos.x;
		sun_center_position[1] = sun_pos.y;
		sun_center_position[2] = sun_pos.z;
	}

	glLightfv(GL_LIGHT1, GL_AMBIENT, sun_ambient);
	glLightfv(GL_LIGHT1, GL_SPECULAR, sun_specular);
	glLightfv(GL_LIGHT1, GL_DIFFUSE, sun_diffuse);
	glLightfv(GL_LIGHT1, GL_POSITION, sun_center_position);

	glEnable(GL_LIGHTING);		// lighting
	glEnable(GL_LIGHT1);		// lighting

	// world's simplest OpenGL optimisations...
	glHint(GL_TRANSFORM_HINT_APPLE, GL_FASTEST);
	glDisable(GL_NORMALIZE);
	glDisable(GL_RESCALE_NORMAL);

	m_glContextInitialized = YES;
}

- (void) snapShot
{
    //NSRect boundsRect = [self bounds];
    int w = viewSize.width;
    int h = viewSize.height;

	if (w & 3)
		w = w + 4 - (w & 3);

    long nPixels = w * h + 1;	

	unsigned char   *red = (unsigned char *) malloc( nPixels);
	unsigned char   *green = (unsigned char *) malloc( nPixels);
	unsigned char   *blue = (unsigned char *) malloc( nPixels);

	NSString	*filepath = [[[NSBundle mainBundle] bundlePath] stringByDeletingLastPathComponent];
	int imageNo = 1;

   // In the GNUstep source, representationUsingType is marked as
   // TODO: and does nothing but return NIL! So for GNUstep we fall
   // back to the methods used in oolite 1.30.
#ifdef GNUSTEP
	NSString	*pathToPic = 
      [filepath stringByAppendingPathComponent:
         [NSString stringWithFormat:@"oolite-%03d.tiff",imageNo]];
	while ([[NSFileManager defaultManager] fileExistsAtPath:pathToPic])
	{
		imageNo++;
		pathToPic = [filepath stringByAppendingPathComponent:[NSString stringWithFormat:@"oolite-%03d.tiff",imageNo]];
	}
#else   
	NSString	*pathToPic = [filepath stringByAppendingPathComponent:[NSString stringWithFormat:@"oolite-%03d.png",imageNo]];
		
	while ([[NSFileManager defaultManager] fileExistsAtPath:pathToPic])
	{
		imageNo++;
		pathToPic = [filepath stringByAppendingPathComponent:[NSString stringWithFormat:@"oolite-%03d.png",imageNo]];
	}

   NSString	*pathToPng = [[pathToPic stringByDeletingPathExtension] stringByAppendingPathExtension:@"png"];
#endif

	NSLog(@">>>>> Snapshot %d x %d file path chosen = %@", w, h, pathToPic);

    NSBitmapImageRep* bitmapRep = 
        [[NSBitmapImageRep alloc]
            initWithBitmapDataPlanes:NULL		// --> let the class allocate it
            pixelsWide:			w
            pixelsHigh:			h
            bitsPerSample:		8		// each component is 8 bits (1 byte)
            samplesPerPixel:	3		// number of components (R, G, B)
            hasAlpha:			NO		// no transparency
            isPlanar:			NO		// data integrated into single plane
            colorSpaceName:		NSDeviceRGBColorSpace
            bytesPerRow:		0		// --> let the class figure it out
            bitsPerPixel:		0		// --> let the class figure it out
        ];

    unsigned char *pixels = [bitmapRep bitmapData];

	glReadPixels(0,0, w,h, GL_RED,   GL_UNSIGNED_BYTE, red);
	glReadPixels(0,0, w,h, GL_GREEN, GL_UNSIGNED_BYTE, green);
	glReadPixels(0,0, w,h, GL_BLUE,  GL_UNSIGNED_BYTE, blue);

	int x,y;
	for (y = 0; y < h; y++)
	{
		long index = (h - y - 1)*w;
		for (x = 0; x < w; x++)		// set bitmap pixels
		{
			*pixels++ = red[index];
			*pixels++ = green[index];
			*pixels++ = blue[index++];
		}
	}

#ifdef GNUSTEP
   NSImage *image=[[NSImage alloc] initWithSize:NSMakeSize(w,h)];
   [image addRepresentation:bitmapRep];
   [[image TIFFRepresentation] writeToFile:pathToPic atomically:YES];
   [image release];
#else
	[[bitmapRep representationUsingType:NSPNGFileType properties:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], NSImageInterlaced, NULL]]
		writeToFile:pathToPng atomically:YES];			// save PNG representation of Image
#endif

	// free allocated objects and memory
	[bitmapRep release];         
	free(red);
	free(green);
	free(blue);
}

- (void)mouseDown:(NSEvent *)theEvent
{
    keys[gvMouseLeftButton] = YES; // 'a' down
}

- (void)mouseUp:(NSEvent *)theEvent
{
	keys[gvMouseLeftButton] = NO;  // 'a' up
}

- (void)mouseDragged:(NSEvent *)theEvent
{
    squareX = [theEvent locationInWindow].x - mouseDragStartPoint.x;
    squareY = [theEvent locationInWindow].y - mouseDragStartPoint.y;
    //[self setNeedsDisplay:YES];
}

- (void)mouseMoved:(NSEvent *)theEvent
{
	double mx = [theEvent locationInWindow].x - viewSize.width/2.0;
	double my = [theEvent locationInWindow].y - viewSize.height/2.0;
		
	if (display_z > 640.0)
	{
		mx /= viewSize.width * MAIN_GUI_PIXEL_WIDTH / display_z;
		my /= viewSize.height;
	}
	else
	{
		mx /= MAIN_GUI_PIXEL_WIDTH * viewSize.width / 640.0;
		my /= MAIN_GUI_PIXEL_HEIGHT * viewSize.width / 640.0;
	}
	
	[self setVirtualJoystick:mx :-my];
}

- (void) setVirtualJoystick:(double) vmx :(double) vmy
{
	virtualJoystickPosition.x = vmx;
	virtualJoystickPosition.y = vmy;
}

- (NSPoint) virtualJoystickPosition
{
	return virtualJoystickPosition;
}


/////////////////////////////////////////////////////////////

- (void) clearKeys
{
	int i;
	for (i = 0; i < [self numKeys]; i++)
		keys[i] = NO;
}

- (BOOL) isDown: (int) key
{
	if ( key < 0 )
		return NO;
	if ( key >= [self numKeys] )
		return NO;
	return keys[key];
}

- (BOOL) isOptDown
{
	return opt;
}

- (BOOL) isCtrlDown
{
	return ctrl;
}

- (BOOL) isCommandDown
{
	return command;
}

- (BOOL) isShiftDown
{
	return shift;
}

- (int) numKeys
{
	return NUM_KEYS;
} 

- (void) pollControls
{
	SDL_Event event;
	SDL_KeyboardEvent* kbd_event;

	while (SDL_PollEvent(&event)) {
		switch (event.type) {
			case SDL_KEYDOWN:
				kbd_event = (SDL_KeyboardEvent*)&event;
				//printf("Keydown scancode: %d\n", kbd_event->keysym.scancode);
				switch (kbd_event->keysym.sym) {
					case SDLK_1: if (shift) { keys[33] = YES; keys[gvNumberKey1] = NO; } else { keys[33] = NO; keys[gvNumberKey1] = YES; } break;
					case SDLK_2: keys[gvNumberKey2] = YES; break;
					case SDLK_3: keys[gvNumberKey3] = YES; break;
					case SDLK_4: keys[gvNumberKey4] = YES; break;
					case SDLK_5: keys[gvNumberKey5] = YES; break;
					case SDLK_6: keys[gvNumberKey6] = YES; break;
					case SDLK_7: keys[gvNumberKey7] = YES; break;
					case SDLK_8: if (shift) { keys[42] = YES; keys[gvNumberKey8] = NO; } else { keys[42] = NO; keys[gvNumberKey8] = YES; } break;
					case SDLK_9: keys[gvNumberKey9] = YES; break;
					case SDLK_0: keys[gvNumberKey0] = YES; break;
					case SDLK_a: if (shift) { keys[65] = YES; keys[97] = NO; } else { keys[65] = NO; keys[97] = YES; } break;
					case SDLK_b: if (shift) { keys[66] = YES; keys[98] = NO; } else { keys[66] = NO; keys[98] = YES; } break;
					case SDLK_c: if (shift) { keys[67] = YES; keys[99] = NO; } else { keys[67] = NO; keys[99] = YES; } break;
					case SDLK_d: if (shift) { keys[68] = YES; keys[100] = NO; } else { keys[68] = NO; keys[100] = YES; } break;
					case SDLK_e: if (shift) { keys[69] = YES; keys[101] = NO; } else { keys[69] = NO; keys[101] = YES; } break;
					case SDLK_f: if (shift) { keys[70] = YES; keys[102] = NO; } else { keys[70] = NO; keys[102] = YES; } break;
					case SDLK_g: if (shift) { keys[71] = YES; keys[103] = NO; } else { keys[71] = NO; keys[103] = YES; } break;
					case SDLK_h: if (shift) { keys[72] = YES; keys[104] = NO; } else { keys[72] = NO; keys[104] = YES; } break;
					case SDLK_i: if (shift) { keys[73] = YES; keys[105] = NO; } else { keys[73] = NO; keys[105] = YES; } break;
					case SDLK_j: if (shift) { keys[74] = YES; keys[106] = NO; } else { keys[74] = NO; keys[106] = YES; } break;
					case SDLK_k: if (shift) { keys[75] = YES; keys[107] = NO; } else { keys[75] = NO; keys[107] = YES; } break;
					case SDLK_l: if (shift) { keys[76] = YES; keys[108] = NO; } else { keys[76] = NO; keys[108] = YES; } break;
					case SDLK_m: if (shift) { keys[77] = YES; keys[109] = NO; } else { keys[77] = NO; keys[109] = YES; } break;
					case SDLK_n: if (shift) { keys[78] = YES; keys[110] = NO; } else { keys[78] = NO; keys[110] = YES; } break;
					case SDLK_o: if (shift) { keys[79] = YES; keys[111] = NO; } else { keys[79] = NO; keys[111] = YES; } break;
					case SDLK_p: if (shift) { keys[80] = YES; keys[112] = NO; } else { keys[80] = NO; keys[112] = YES; } break;
					case SDLK_q: if (shift) { keys[81] = YES; keys[113] = NO; } else { keys[81] = NO; keys[113] = YES; } break;
					case SDLK_r: if (shift) { keys[82] = YES; keys[114] = NO; } else { keys[82] = NO; keys[114] = YES; } break;
					case SDLK_s: if (shift) { keys[83] = YES; keys[115] = NO; } else { keys[83] = NO; keys[115] = YES; } break;
					case SDLK_t: if (shift) { keys[84] = YES; keys[116] = NO; } else { keys[84] = NO; keys[116] = YES; } break;
					case SDLK_u: if (shift) { keys[85] = YES; keys[117] = NO; } else { keys[85] = NO; keys[117] = YES; } break;
					case SDLK_v: if (shift) { keys[86] = YES; keys[118] = NO; } else { keys[86] = NO; keys[118] = YES; } break;
					case SDLK_w: if (shift) { keys[87] = YES; keys[119] = NO; } else { keys[87] = NO; keys[119] = YES; } break;
					case SDLK_x: if (shift) { keys[88] = YES; keys[120] = NO; } else { keys[88] = NO; keys[120] = YES; } break;
					case SDLK_y: if (shift) { keys[89] = YES; keys[121] = NO; } else { keys[89] = NO; keys[121] = YES; } break;
					case SDLK_z: if (shift) { keys[90] = YES; keys[122] = NO; } else { keys[90] = NO; keys[122] = YES; } break;
					case SDLK_BACKSLASH: if (! shift) keys[92] = YES; break;
					case SDLK_BACKQUOTE: if (! shift) keys[96] = YES; break;
					case SDLK_HOME: keys[gvHomeKey] = YES; break;
					case SDLK_SPACE: keys[32] = YES; break;
					case SDLK_RETURN: keys[13] = YES; break;
					case SDLK_TAB: keys[9] = YES; break;
					case SDLK_UP: keys[gvArrowKeyUp] = YES; break;
					case SDLK_DOWN: keys[gvArrowKeyDown] = YES; break;
					case SDLK_LEFT: keys[gvArrowKeyLeft] = YES; break;
					case SDLK_RIGHT: keys[gvArrowKeyRight] = YES; break;

					case SDLK_F1: keys[gvFunctionKey1] = YES; break;
					case SDLK_F2: keys[gvFunctionKey2] = YES; break;
					case SDLK_F3: keys[gvFunctionKey3] = YES; break;
					case SDLK_F4: keys[gvFunctionKey4] = YES; break;
					case SDLK_F5: keys[gvFunctionKey5] = YES; break;
					case SDLK_F6: keys[gvFunctionKey6] = YES; break;
					case SDLK_F7: keys[gvFunctionKey7] = YES; break;
					case SDLK_F8: keys[gvFunctionKey8] = YES; break;
					case SDLK_F9: keys[gvFunctionKey9] = YES; break;
					case SDLK_F10: keys[gvFunctionKey10] = YES; break;

					case SDLK_LSHIFT:
					case SDLK_RSHIFT:
						shift = YES;
						break;

					case SDLK_LCTRL:
					case SDLK_RCTRL:
						ctrl = YES;
						break;

					case SDLK_F11:
						currentSize++;
						if (currentSize > 2)
							currentSize = 0;
						[self initialiseGLWithSize:screenSizes[currentSize]];
						break;

					case SDLK_F12:
						if (fullScreen == NO)
							fullScreen = YES;
						else
							fullScreen = NO;
						[self initialiseGLWithSize:screenSizes[currentSize]];
						break;

					case SDLK_ESCAPE:
						if (shift)
						{
							SDL_FreeSurface(surface);
							SDL_Quit();
							[gameController exitApp];
						}
						else
							keys[27] = YES;
				}
				break;

			case SDL_KEYUP:
				kbd_event = (SDL_KeyboardEvent*)&event;
				//printf("Keydown scancode: %d\n", kbd_event->keysym.scancode);
				switch (kbd_event->keysym.sym) {
					case SDLK_1: keys[33] = NO; keys[gvNumberKey1] = NO; break;
					case SDLK_2: keys[gvNumberKey2] = NO; break;
					case SDLK_3: keys[gvNumberKey3] = NO; break;
					case SDLK_4: keys[gvNumberKey4] = NO; break;
					case SDLK_5: keys[gvNumberKey5] = NO; break;
					case SDLK_6: keys[gvNumberKey6] = NO; break;
					case SDLK_7: keys[gvNumberKey7] = NO; break;
					case SDLK_8: keys[42] = NO; keys[gvNumberKey8] = NO; break;
					case SDLK_9: keys[gvNumberKey9] = NO; break;
					case SDLK_0: keys[gvNumberKey0] = NO; break;
					case SDLK_a: keys[65] = NO; keys[97] = NO; break;
					case SDLK_b: keys[66] = NO; keys[98] = NO; break;
					case SDLK_c: keys[67] = NO; keys[99] = NO; break;
					case SDLK_d: keys[68] = NO; keys[100] = NO; break;
					case SDLK_e: keys[69] = NO; keys[101] = NO; break;
					case SDLK_f: keys[70] = NO; keys[102] = NO; break;
					case SDLK_g: keys[71] = NO; keys[103] = NO; break;
					case SDLK_h: keys[72] = NO; keys[104] = NO; break;
					case SDLK_i: keys[73] = NO; keys[105] = NO; break;
					case SDLK_j: keys[74] = NO; keys[106] = NO; break;
					case SDLK_k: keys[75] = NO; keys[107] = NO; break;
					case SDLK_l: keys[76] = NO; keys[108] = NO; break;
					case SDLK_m: keys[77] = NO; keys[109] = NO; break;
					case SDLK_n: keys[78] = NO; keys[110] = NO; break;
					case SDLK_o: keys[79] = NO; keys[111] = NO; break;
					case SDLK_p: keys[80] = NO; keys[112] = NO; break;
					case SDLK_q: keys[81] = NO; keys[113] = NO; break;
					case SDLK_r: keys[82] = NO; keys[114] = NO; break;
					case SDLK_s: keys[83] = NO; keys[115] = NO; break;
					case SDLK_t: keys[84] = NO; keys[116] = NO; break;
					case SDLK_u: keys[85] = NO; keys[117] = NO; break;
					case SDLK_v: keys[86] = NO; keys[118] = NO; break;
					case SDLK_w: keys[87] = NO; keys[119] = NO; break;
					case SDLK_x: keys[88] = NO; keys[120] = NO; break;
					case SDLK_y: keys[89] = NO; keys[121] = NO; break;
					case SDLK_z: keys[90] = NO; keys[122] = NO; break;
					case SDLK_BACKSLASH: keys[92] = NO; break;
					case SDLK_BACKQUOTE: keys[96] = NO; break;
					case SDLK_HOME: keys[gvHomeKey] = NO; break;
					case SDLK_SPACE: keys[32] = NO; break;
					case SDLK_RETURN: keys[13] = NO; break;
					case SDLK_TAB: keys[9] = NO; break;
					case SDLK_UP: keys[gvArrowKeyUp] = NO; break;
					case SDLK_DOWN: keys[gvArrowKeyDown] = NO; break;
					case SDLK_LEFT: keys[gvArrowKeyLeft] = NO; break;
					case SDLK_RIGHT: keys[gvArrowKeyRight] = NO; break;

					case SDLK_F1: keys[gvFunctionKey1] = NO; break;
					case SDLK_F2: keys[gvFunctionKey2] = NO; break;
					case SDLK_F3: keys[gvFunctionKey3] = NO; break;
					case SDLK_F4: keys[gvFunctionKey4] = NO; break;
					case SDLK_F5: keys[gvFunctionKey5] = NO; break;
					case SDLK_F6: keys[gvFunctionKey6] = NO; break;
					case SDLK_F7: keys[gvFunctionKey7] = NO; break;
					case SDLK_F8: keys[gvFunctionKey8] = NO; break;
					case SDLK_F9: keys[gvFunctionKey9] = NO; break;
					case SDLK_F10: keys[gvFunctionKey10] = NO; break;

					case SDLK_LSHIFT:
					case SDLK_RSHIFT:
						shift = NO;
						break;

					case SDLK_LCTRL:
					case SDLK_RCTRL:
						ctrl = NO;
						break;

					case SDLK_ESCAPE:
						keys[27] = NO;
						break;
				}
				break;
		}
	}
}

@end
