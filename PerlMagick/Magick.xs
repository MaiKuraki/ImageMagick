/*
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                                                                             %
%                                                                             %
%                         PPPP   EEEEE  RRRR   L                              %
%                         P   P  E      R   R  L                              %
%                         PPPP   EEE    RRRR   L                              %
%                         P      E      R  R   L                              %
%                         P      EEEEE  R   R  LLLLL                          %
%                                                                             %
%                  M   M   AAA    GGGG  IIIII   CCCC  K   K                   %
%                  MM MM  A   A  G        I    C      K  K                    %
%                  M M M  AAAAA  G GGG    I    C      KKK                     %
%                  M   M  A   A  G   G    I    C      K  K                    %
%                  M   M  A   A   GGGG  IIIII   CCCC  K   K                   %
%                                                                             %
%                                                                             %
%                Object-oriented Perl interface to ImageMagick                %
%                                                                             %
%                            Software Design                                  %
%                              Kyle Shorter                                   %
%                                 Cristy                                      %
%                             February 1997                                   %
%                                                                             %
%                                                                             %
%  Copyright @ 1999 ImageMagick Studio LLC, a non-profit organization         %
%  dedicated to making software imaging solutions freely available.           %
%                                                                             %
%  You may not use this file except in compliance with the License.  You may  %
%  obtain a copy of the License at                                            %
%                                                                             %
%    https://imagemagick.org/script/license.php                               %
%                                                                             %
%  Unless required by applicable law or agreed to in writing, software        %
%  distributed under the License is distributed on an "AS IS" BASIS,          %
%  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.   %
%  See the License for the specific language governing permissions and        %
%  limitations under the License.                                             %
%                                                                             %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%  PerlMagick is an objected-oriented Perl interface to ImageMagick.  Use
%  the module to read, manipulate, or write an image or image sequence from
%  within a Perl script.  This makes PerlMagick suitable for Web CGI scripts.
%
*/

/*
  Include declarations.
*/
#if defined(__cplusplus) || defined(c_plusplus)
extern "C" {
#endif

#define PERL_NO_GET_CONTEXT
#include <MagickCore/MagickCore.h>
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include <math.h>
#undef tainted

#if defined(__cplusplus) || defined(c_plusplus)
}
#endif

/*
  Define declarations.
*/
#ifndef aTHX_
#define aTHX_
#define pTHX_
#define dTHX
#endif
#define DegreesToRadians(x)  (MagickPI*(x)/180.0)
#define EndOf(array)  (&array[NumberOf(array)])
#define MagickPI  3.14159265358979323846264338327950288419716939937510
#define MaxArguments  35
#ifndef na
#define na  PL_na
#endif
#define NumberOf(array)  (sizeof(array)/sizeof(*array))
#define PackageName   "Image::Magick"
#if PERL_VERSION <= 6
#define PerlIO  FILE
#define PerlIO_importFILE(f, fl)  (f)
#define PerlIO_findFILE(f)  NULL
#endif
#ifndef sv_undef
#define sv_undef  PL_sv_undef
#endif

#define AddImageToRegistry(sv,image) \
{ \
  if (magick_registry != (SplayTreeInfo *) NULL) \
    { \
      (void) AddValueToSplayTree(magick_registry,image,image); \
      (sv)=newSViv(PTR2IV(image)); \
    } \
}

#define DeleteImageFromRegistry(reference,image) \
{ \
  if (magick_registry != (SplayTreeInfo *) NULL) \
    { \
      if (GetImageReferenceCount(image) == 1) \
       (void) DeleteNodeByValueFromSplayTree(magick_registry,image); \
      image=DestroyImage(image); \
      sv_setiv(reference,0); \
    } \
}

#define InheritPerlException(exception,perl_exception) \
{ \
  char \
    message[MagickPathExtent]; \
 \
  if ((exception)->severity != UndefinedException) \
    { \
      (void) FormatLocaleString(message,MagickPathExtent,"Exception %d: %s%s%s%s",\
        (exception)->severity, (exception)->reason ? \
        GetLocaleExceptionMessage((exception)->severity,(exception)->reason) : \
        "Unknown", (exception)->description ? " (" : "", \
        (exception)->description ? GetLocaleExceptionMessage( \
        (exception)->severity,(exception)->description) : "", \
        (exception)->description ? ")" : ""); \
      if ((perl_exception) != (SV *) NULL) \
        { \
          if (SvCUR(perl_exception)) \
            sv_catpv(perl_exception,"\n"); \
          sv_catpv(perl_exception,message); \
        } \
    } \
}

#define ThrowPerlException(exception,severity,tag,reason) \
  (void) ThrowMagickException(exception,GetMagickModule(),severity, \
    tag,"`%s'",reason); \

/*
  Typedef and structure declarations.
*/
typedef enum
{
  NullReference = 0,
  ArrayReference = (~0),
  RealReference = (~0)-1,
  FileReference = (~0)-2,
  ImageReference = (~0)-3,
  IntegerReference = (~0)-4,
  StringReference = (~0)-5
} MagickReference;

typedef struct _Arguments
{
  const char
    *method;

  ssize_t
    type;
} Arguments;

struct ArgumentList
{
  ssize_t
    integer_reference;

  double
    real_reference;

  const char
    *string_reference;

  Image
    *image_reference;

  SV
    *array_reference;

  FILE
    *file_reference;

  size_t
    length;
};

struct PackageInfo
{
  ImageInfo
    *image_info;
};

typedef void
  *Image__Magick;  /* data type for the Image::Magick package */

/*
  Static declarations.
*/
static struct
  Methods
  {
    const char
      *name;

    Arguments
      arguments[MaxArguments];
  } Methods[] =
  {
    { "Comment", { {"comment", StringReference} } },
    { "Label", { {"label", StringReference} } },
    { "AddNoise", { {"noise", MagickNoiseOptions}, {"attenuate", RealReference},
      {"channel", MagickChannelOptions} } },
    { "Colorize", { {"fill", StringReference}, {"blend", StringReference} } },
    { "Border", { {"geometry", StringReference}, {"width", IntegerReference},
      {"height", IntegerReference}, {"fill", StringReference},
      {"bordercolor", StringReference}, {"color", StringReference},
      {"compose", MagickComposeOptions} } },
    { "Blur", { {"geometry", StringReference}, {"radius", RealReference},
      {"sigma", RealReference}, {"channel", MagickChannelOptions} } },
    { "Chop", { {"geometry", StringReference}, {"width", IntegerReference},
      {"height", IntegerReference}, {"x", IntegerReference},
      {"y", IntegerReference}, {"gravity", MagickGravityOptions} } },
    { "Crop", { {"geometry", StringReference}, {"width", IntegerReference},
      {"height", IntegerReference}, {"x", IntegerReference},
      {"y", IntegerReference}, {"fuzz", StringReference},
      {"gravity", MagickGravityOptions} } },
    { "Despeckle", { { (const char *) NULL, NullReference } } },
    { "Edge", { {"radius", RealReference} } },
    { "Emboss", { {"geometry", StringReference}, {"radius", RealReference},
      {"sigma", RealReference} } },
    { "Enhance", { { (const char *) NULL, NullReference } } },
    { "Flip", { { (const char *) NULL, NullReference } } },
    { "Flop", { { (const char *) NULL, NullReference } } },
    { "Frame", { {"geometry", StringReference}, {"width", IntegerReference},
      {"height", IntegerReference}, {"inner", IntegerReference},
      {"outer", IntegerReference}, {"fill", StringReference},
      {"color", StringReference}, {"compose", MagickComposeOptions} } },
    { "Implode", { {"amount", RealReference},
      {"interpolate", MagickInterpolateOptions} } },
    { "Magnify", { { (const char *) NULL, NullReference } } },
    { "MedianFilter", { {"geometry", StringReference},
      {"width", IntegerReference}, {"height", IntegerReference},
      {"channel", MagickChannelOptions} } },
    { "Minify", { { (const char *) NULL, NullReference } } },
    { "OilPaint", { {"radius", RealReference}, {"sigma", RealReference} } },
    { "ReduceNoise", { {"geometry", StringReference},
      {"width", IntegerReference},{"height", IntegerReference},
      {"channel", MagickChannelOptions} } },
    { "Roll", { {"geometry", StringReference}, {"x", IntegerReference},
      {"y", IntegerReference} } },
    { "Rotate", { {"degrees", RealReference},
      {"background", StringReference} } },
    { "Sample", { {"geometry", StringReference}, {"width", IntegerReference},
      {"height", IntegerReference} } },
    { "Scale", { {"geometry", StringReference}, {"width", IntegerReference},
      {"height", IntegerReference} } },
    { "Shade", { {"geometry", StringReference}, {"azimuth", RealReference},
      {"elevation", RealReference}, {"gray", MagickBooleanOptions} } },
    { "Sharpen", { {"geometry", StringReference}, {"radius", RealReference},
      {"sigma", RealReference}, {"channel", MagickChannelOptions} } },
    { "Shear", { {"geometry", StringReference}, {"x", RealReference},
      {"y", RealReference}, { "fill", StringReference},
      {"color", StringReference} } },
    { "Spread", { {"radius", RealReference},
      {"interpolate", MagickInterpolateOptions} } },
    { "Swirl", { {"degrees", RealReference},
      {"interpolate", MagickInterpolateOptions} } },
    { "Resize", { {"geometry", StringReference}, {"width", IntegerReference},
      {"height", IntegerReference}, {"filter", MagickFilterOptions},
      {"support", StringReference } } },
    { "Zoom", { {"geometry", StringReference}, {"width", IntegerReference},
      {"height", IntegerReference}, {"filter", MagickFilterOptions},
      {"support", RealReference } } },
    { "Annotate", { {"text", StringReference}, {"font", StringReference},
      {"pointsize", RealReference}, {"density", StringReference},
      {"undercolor", StringReference}, {"stroke", StringReference},
      {"fill", StringReference}, {"geometry", StringReference},
      {"sans", StringReference}, {"x", RealReference},
      {"y", RealReference}, {"gravity", MagickGravityOptions},
      {"translate", StringReference}, {"scale", StringReference},
      {"rotate", RealReference}, {"skewX", RealReference},
      {"skewY", RealReference}, {"strokewidth", RealReference},
      {"antialias", MagickBooleanOptions}, {"family", StringReference},
      {"style", MagickStyleOptions}, {"stretch", MagickStretchOptions},
      {"weight", IntegerReference}, {"align", MagickAlignOptions},
      {"encoding", StringReference}, {"affine", ArrayReference},
      {"fill-pattern", ImageReference}, {"stroke-pattern", ImageReference},
      {"tile", ImageReference}, {"kerning", RealReference},
      {"interline-spacing", RealReference},
      {"interword-spacing", RealReference},
      {"direction", MagickDirectionOptions},
      {"decorate", MagickDecorateOptions},
      {"word-break", MagickWordBreakOptions} } },
    { "ColorFloodfill", { {"geometry", StringReference},
      {"x", IntegerReference}, {"y", IntegerReference},
      {"fill", StringReference}, {"bordercolor", StringReference},
      {"fuzz", StringReference}, {"invert", MagickBooleanOptions} } },
    { "Composite", { {"image", ImageReference},
      {"compose", MagickComposeOptions}, {"geometry", StringReference},
      {"x", IntegerReference}, {"y", IntegerReference},
      {"gravity", MagickGravityOptions}, {"opacity", StringReference},
      {"tile", MagickBooleanOptions}, {"rotate", RealReference},
      {"color", StringReference}, {"mask", ImageReference},
      {"channel", MagickChannelOptions},
      {"interpolate", MagickInterpolateOptions}, {"args", StringReference},
      {"blend", StringReference}, {"clip-to-self", MagickBooleanOptions} } },
    { "Contrast", { {"sharpen", MagickBooleanOptions} } },
    { "CycleColormap", { {"display", IntegerReference} } },
    { "Draw", { {"primitive", MagickPrimitiveOptions},
      {"points", StringReference}, {"method", MagickMethodOptions},
      {"stroke", StringReference}, {"fill", StringReference},
      {"strokewidth", RealReference}, {"font", StringReference},
      {"bordercolor", StringReference}, {"x", RealReference},
      {"y", RealReference}, {"translate", StringReference},
      {"scale", StringReference}, {"rotate", RealReference},
      {"skewX", RealReference}, {"skewY", RealReference},
      {"tile", ImageReference}, {"pointsize", RealReference},
      {"antialias", MagickBooleanOptions}, {"density", StringReference},
      {"linewidth", RealReference}, {"affine", ArrayReference},
      {"stroke-dashoffset", RealReference},
      {"stroke-dasharray", ArrayReference},
      {"interpolate", MagickInterpolateOptions},
      {"origin", StringReference}, {"text", StringReference},
      {"fill-pattern", ImageReference}, {"stroke-pattern", ImageReference},
      {"vector-graphics", StringReference}, {"kerning", RealReference},
      {"interline-spacing", RealReference},
      {"interword-spacing", RealReference},
      {"direction", MagickDirectionOptions},
      {"word-break", MagickWordBreakOptions} } },
    { "Equalize", { {"channel", MagickChannelOptions} } },
    { "Gamma", { {"gamma", StringReference}, {"channel", MagickChannelOptions},
      {"red", RealReference}, {"green", RealReference},
      {"blue", RealReference} } },
    { "Map", { {"image", ImageReference},
      {"dither-method", MagickDitherOptions} } },
    { "MatteFloodfill", { {"geometry", StringReference},
      {"x", IntegerReference}, {"y", IntegerReference},
      {"opacity", StringReference}, {"bordercolor", StringReference},
      {"fuzz", StringReference}, {"invert", MagickBooleanOptions} } },
    { "Modulate", { {"factor", StringReference}, {"hue", RealReference},
      {"saturation", RealReference}, {"whiteness", RealReference},
      {"brightness", RealReference}, {"lightness", RealReference},
      {"blackness", RealReference} } },
    { "Negate", { {"gray", MagickBooleanOptions},
      {"channel", MagickChannelOptions} } },
    { "Normalize", { {"channel", MagickChannelOptions} } },
    { "NumberColors", { { (const char *) NULL, NullReference } } },
    { "Opaque", { {"color", StringReference}, {"fill", StringReference},
      {"fuzz", StringReference}, {"channel", MagickChannelOptions},
      {"invert", MagickBooleanOptions} } },
    { "Quantize", { {"colors", IntegerReference},
      {"treedepth", IntegerReference}, {"colorspace", MagickColorspaceOptions},
      {"dither", MagickDitherOptions}, {"measure", MagickBooleanOptions},
      {"global", MagickBooleanOptions}, {"transparent-color", StringReference},
      {"dither-method", MagickDitherOptions} } },
    { "Raise", { {"geometry", StringReference}, {"width", IntegerReference},
      {"height", IntegerReference}, {"raise", MagickBooleanOptions} } },
    { "Segment", { {"geometry", StringReference},
      {"cluster-threshold", RealReference},
      {"smoothing-threshold", RealReference},
      {"colorspace", MagickColorspaceOptions},
      {"verbose", MagickBooleanOptions} } },
    { "Signature", { { (const char *) NULL, NullReference } } },
    { "Solarize", { {"geometry", StringReference},
      {"threshold", StringReference} } },
    { "Sync", { { (const char *) NULL, NullReference } } },
    { "Texture", { {"texture", ImageReference} } },
    { "Evaluate", { {"value", RealReference},
      {"operator", MagickEvaluateOptions},
      {"channel", MagickChannelOptions} } },
    { "Transparent", { {"color", StringReference}, {"opacity", StringReference},
      {"fuzz", StringReference}, {"invert", MagickBooleanOptions} } },
    { "Threshold", { {"threshold", StringReference},
      {"channel", MagickChannelOptions} } },
    { "Charcoal", { {"geometry", StringReference}, {"radius", RealReference},
      {"sigma", RealReference} } },
    { "Trim", { {"fuzz", StringReference} } },
    { "Wave", { {"geometry", StringReference}, {"amplitude", RealReference},
      {"wavelength", RealReference},
      {"interpolate", MagickInterpolateOptions} } },
    { "Separate", { {"channel", MagickChannelOptions} } },
    { "Condense", { { (const char *) NULL, NullReference } } },
    { "Stereo", { {"image", ImageReference}, {"x", IntegerReference},
      {"y", IntegerReference} } },
    { "Stegano", { {"image", ImageReference}, {"offset", IntegerReference} } },
    { "Deconstruct", { { (const char *) NULL, NullReference } } },
    { "GaussianBlur", { {"geometry", StringReference},
      {"radius", RealReference}, {"sigma", RealReference},
      {"channel", MagickChannelOptions} } },
    { "Convolve", { {"coefficients", ArrayReference},
      {"channel", MagickChannelOptions}, {"bias", StringReference},
      {"kernel", StringReference} } },
    { "Profile", { {"name", StringReference}, {"profile", StringReference},
      { "rendering-intent", MagickIntentOptions},
      { "black-point-compensation", MagickBooleanOptions} } },
    { "UnsharpMask", { {"geometry", StringReference},
      {"radius", RealReference}, {"sigma", RealReference},
      {"gain", RealReference}, {"threshold", RealReference},
      {"channel", MagickChannelOptions} } },
    { "MotionBlur", { {"geometry", StringReference},
      {"radius", RealReference}, {"sigma", RealReference},
      {"angle", RealReference}, {"channel", MagickChannelOptions} } },
    { "OrderedDither", { {"threshold", StringReference},
      {"channel", MagickChannelOptions} } },
    { "Shave", { {"geometry", StringReference}, {"width", IntegerReference},
      {"height", IntegerReference} } },
    { "Level", { {"levels", StringReference}, {"black-point", RealReference},
      {"white-point", RealReference}, {"gamma", RealReference},
      {"channel", MagickChannelOptions}, {"level", StringReference} } },
    { "Clip", { {"id", StringReference}, {"inside", MagickBooleanOptions} } },
    { "AffineTransform", { {"affine", ArrayReference},
      {"translate", StringReference}, {"scale", StringReference},
      {"rotate", RealReference}, {"skewX", RealReference},
      {"skewY", RealReference}, {"interpolate", MagickInterpolateOptions},
      {"background", StringReference} } },
    { "Difference", { {"image", ImageReference}, {"fuzz", StringReference} } },
    { "AdaptiveThreshold", { {"geometry", StringReference},
      {"width", IntegerReference}, {"height", IntegerReference},
      {"bias", RealReference} } },
    { "Resample", { {"density", StringReference}, {"x", RealReference},
      {"y", RealReference}, {"filter", MagickFilterOptions},
      {"support", RealReference } } },
    { "Describe", { {"file", FileReference} } },
    { "BlackThreshold", { {"threshold", StringReference},
      {"channel", MagickChannelOptions} } },
    { "WhiteThreshold", { {"threshold", StringReference},
      {"channel", MagickChannelOptions} } },
    { "RotationalBlur", { {"geometry", StringReference},
      {"angle", RealReference}, {"channel", MagickChannelOptions} } },
    { "Thumbnail", { {"geometry", StringReference}, {"width", IntegerReference},
      {"height", IntegerReference} } },
    { "Strip", { { (const char *) NULL, NullReference } } },
    { "Tint", { {"fill", StringReference}, {"blend", StringReference} } },
    { "Channel", { {"channel", MagickChannelOptions} } },
    { "Splice", { {"geometry", StringReference}, {"width", IntegerReference},
      {"height", IntegerReference}, {"x", IntegerReference},
      {"y", IntegerReference}, {"fuzz", StringReference},
      {"background", StringReference}, {"gravity", MagickGravityOptions} } },
    { "Posterize", { {"levels", IntegerReference},
      {"dither", MagickBooleanOptions} } },
    { "Shadow", { {"geometry", StringReference}, {"alpha", RealReference},
      {"sigma", RealReference}, {"x", IntegerReference},
      {"y", IntegerReference} } },
    { "Identify", { {"file", FileReference}, {"features", StringReference},
      {"moments", MagickBooleanOptions}, {"unique", MagickBooleanOptions} } },
    { "SepiaTone", { {"threshold", RealReference} } },
    { "SigmoidalContrast", { {"geometry", StringReference},
      {"contrast", RealReference}, {"mid-point", RealReference},
      {"channel", MagickChannelOptions}, {"sharpen", MagickBooleanOptions} } },
    { "Extent", { {"geometry", StringReference}, {"width", IntegerReference},
      {"height", IntegerReference}, {"x", IntegerReference},
      {"y", IntegerReference}, {"fuzz", StringReference},
      {"background", StringReference}, {"gravity", MagickGravityOptions} } },
    { "Vignette", { {"geometry", StringReference}, {"radius", RealReference},
      {"sigma", RealReference}, {"x", IntegerReference},
      {"y", IntegerReference}, {"background", StringReference} } },
    { "ContrastStretch", { {"levels", StringReference},
      {"black-point", RealReference},{"white-point", RealReference},
      {"channel", MagickChannelOptions} } },
    { "Sans0", { { (const char *) NULL, NullReference } } },
    { "Sans1", { { (const char *) NULL, NullReference } } },
    { "AdaptiveSharpen", { {"geometry", StringReference},
      {"radius", RealReference}, {"sigma", RealReference},
      {"bias", RealReference}, {"channel", MagickChannelOptions} } },
    { "Transpose", { { (const char *) NULL, NullReference } } },
    { "Transverse", { { (const char *) NULL, NullReference } } },
    { "AutoOrient", { { (const char *) NULL, NullReference } } },
    { "AdaptiveBlur", { {"geometry", StringReference},
      {"radius", RealReference}, {"sigma", RealReference},
      {"channel", MagickChannelOptions} } },
    { "Sketch", { {"geometry", StringReference},
      {"radius", RealReference}, {"sigma", RealReference},
      {"angle", RealReference} } },
    { "UniqueColors", { { (const char *) NULL, NullReference } } },
    { "AdaptiveResize", { {"geometry", StringReference},
      {"width", IntegerReference}, {"height", IntegerReference},
      {"filter", MagickFilterOptions}, {"support", StringReference },
      {"blur", RealReference } } },
    { "ClipMask", { {"mask", ImageReference} } },
    { "LinearStretch", { {"levels", StringReference},
      {"black-point", RealReference},{"white-point", RealReference} } },
    { "ColorMatrix", { {"matrix", ArrayReference} } },
    { "Mask", { {"mask", ImageReference} } },
    { "Polaroid", { {"caption", StringReference}, {"angle", RealReference},
      {"font", StringReference}, {"stroke", StringReference},
      {"fill", StringReference}, {"strokewidth", RealReference},
      {"pointsize", RealReference}, {"gravity", MagickGravityOptions},
      {"background", StringReference},
      {"interpolate", MagickInterpolateOptions} } },
    { "FloodfillPaint", { {"geometry", StringReference},
      {"x", IntegerReference}, {"y", IntegerReference},
      {"fill", StringReference}, {"bordercolor", StringReference},
      {"fuzz", StringReference}, {"channel", MagickChannelOptions},
      {"invert", MagickBooleanOptions} } },
    { "Distort", { {"points", ArrayReference}, {"method", MagickDistortOptions},
      {"virtual-pixel", MagickVirtualPixelOptions},
      {"best-fit", MagickBooleanOptions} } },
    { "Clut", { {"image", ImageReference},
      {"interpolate", MagickInterpolateOptions},
      {"channel", MagickChannelOptions} } },
    { "LiquidRescale", { {"geometry", StringReference},
      {"width", IntegerReference}, {"height", IntegerReference},
      {"delta-x", RealReference}, {"rigidity", RealReference } } },
    { "Encipher", { {"passphrase", StringReference} } },
    { "Decipher", { {"passphrase", StringReference} } },
    { "Deskew", { {"geometry", StringReference},
      {"threshold", StringReference} } },
    { "Remap", { {"image", ImageReference},
      {"dither-method", MagickDitherOptions} } },
    { "SparseColor", { {"points", ArrayReference},
      {"method", MagickSparseColorOptions},
      {"virtual-pixel", MagickVirtualPixelOptions},
      {"channel", MagickChannelOptions} } },
    { "Function", { {"parameters", ArrayReference},
      {"function", MagickFunctionOptions},
      {"virtual-pixel", MagickVirtualPixelOptions} } },
    { "SelectiveBlur", { {"geometry", StringReference},
      {"radius", RealReference}, {"sigma", RealReference},
      {"threshold", RealReference}, {"channel", MagickChannelOptions} } },
    { "HaldClut", { {"image", ImageReference},
      {"channel", MagickChannelOptions} } },
    { "BlueShift", { {"factor", StringReference} } },
    { "ForwardFourierTransform", { {"magnitude", MagickBooleanOptions} } },
    { "InverseFourierTransform", { {"magnitude", MagickBooleanOptions} } },
    { "ColorDecisionList", {
      {"color-correction-collection", StringReference} } },
    { "AutoGamma", { {"channel", MagickChannelOptions} } },
    { "AutoLevel", { {"channel", MagickChannelOptions} } },
    { "LevelColors", { {"invert", MagickBooleanOptions},
      {"black-point", StringReference}, {"white-point", StringReference},
      {"channel", MagickChannelOptions}, {"invert", MagickBooleanOptions} } },
    { "Clamp", { {"channel", MagickChannelOptions} } },
    { "BrightnessContrast", { {"levels", StringReference},
      {"brightness", RealReference},{"contrast", RealReference},
      {"channel", MagickChannelOptions} } },
    { "Morphology", { {"kernel", StringReference},
      {"channel", MagickChannelOptions}, {"method", MagickMorphologyOptions},
      {"iterations", IntegerReference} } },
    { "Mode", { {"geometry", StringReference},
      {"width", IntegerReference},{"height", IntegerReference},
      {"channel", MagickChannelOptions} } },
    { "Statistic", { {"geometry", StringReference},
      {"width", IntegerReference},{"height", IntegerReference},
      {"channel", MagickChannelOptions}, {"type", MagickStatisticOptions} } },
    { "Perceptible", { {"epsilon", RealReference},
      {"channel", MagickChannelOptions} } },
    { "Poly", { {"terms", ArrayReference},
      {"channel", MagickChannelOptions} } },
    { "Grayscale", { {"method", MagickNoiseOptions} } },
    { "CannyEdge", { {"geometry", StringReference},
      {"radius", RealReference}, {"sigma", RealReference},
      {"lower-percent", RealReference}, {"upper-percent", RealReference} } },
    { "HoughLine", { {"geometry", StringReference},
      {"width", IntegerReference}, {"height", IntegerReference},
      {"threshold", IntegerReference} } },
    { "MeanShift", { {"geometry", StringReference},
      {"width", IntegerReference}, {"height", IntegerReference},
      {"distance", RealReference} } },
    { "Kuwahara", { {"geometry", StringReference}, {"radius", RealReference},
      {"sigma", RealReference}, {"channel", MagickChannelOptions} } },
    { "ConnectedComponents", { {"connectivity", IntegerReference} } },
    { "CopyPixels", { {"image", ImageReference}, {"geometry", StringReference},
      {"width", IntegerReference}, {"height", IntegerReference},
      {"x", IntegerReference}, {"y", IntegerReference},
      {"gravity", MagickGravityOptions}, {"offset", StringReference},
      {"dx", IntegerReference}, {"dy", IntegerReference} } },
    { "Color", { {"color", StringReference} } },
    { "WaveletDenoise", {  {"geometry", StringReference},
      {"threshold", RealReference}, {"softness", RealReference},
      {"channel", MagickChannelOptions} } },
    { "Colorspace", { {"colorspace", MagickColorspaceOptions} } },
    { "AutoThreshold", { {"method", MagickAutoThresholdOptions} } },
    { "RangeThreshold", { {"geometry", StringReference},
      {"low-black", RealReference}, {"low-white", RealReference},
      {"high-white", RealReference}, {"high-black", RealReference},
      {"channel", MagickChannelOptions} } },
    { "CLAHE", { {"geometry", StringReference}, {"width", IntegerReference},
      {"height", IntegerReference}, {"number-bins", IntegerReference},
      {"clip-limit", RealReference} } },
    { "Kmeans", { {"geometry", StringReference}, {"colors", IntegerReference},
      {"iterations", IntegerReference}, {"tolerance", RealReference} } },
    { "ColorThreshold", { {"start-color", StringReference},
      {"stop-color", StringReference}, {"channel", MagickChannelOptions} } },
    { "WhiteBalance", { { (const char *) NULL, NullReference } } },
    { "BilateralBlur", { {"geometry", StringReference},
      {"width", IntegerReference}, {"height", IntegerReference},
      {"intensity-sigma", RealReference}, {"spatial-sigma", RealReference},
      {"channel", MagickChannelOptions} } },
    { "SortPixels", { { (const char *) NULL, NullReference } } },
    { "Integral", { { (const char *) NULL, NullReference } } },
  };

static SplayTreeInfo
  *magick_registry = (SplayTreeInfo *) NULL;

/*
  Forward declarations.
*/
static Image
  *SetupList(pTHX_ SV *,struct PackageInfo **,SV ***,ExceptionInfo *);

static ssize_t
  strEQcase(const char *,const char *);

/*
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                                                                             %
%                                                                             %
%                                                                             %
%   C l o n e P a c k a g e I n f o                                           %
%                                                                             %
%                                                                             %
%                                                                             %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%  ClonePackageInfo makes a duplicate of the given info, or if info is NULL,
%  a new one.
%
%  The format of the ClonePackageInfo routine is:
%
%      struct PackageInfo *ClonePackageInfo(struct PackageInfo *info,
%        exception)
%
%  A description of each parameter follows:
%
%    o info: a structure of type info.
%
%    o exception: Return any errors or warnings in this structure.
%
*/
static struct PackageInfo *ClonePackageInfo(struct PackageInfo *info,
  ExceptionInfo *exception)
{
  struct PackageInfo
    *clone_info;

  clone_info=(struct PackageInfo *) AcquireQuantumMemory(1,sizeof(*clone_info));
  if (clone_info == (struct PackageInfo *) NULL)
    {
      ThrowPerlException(exception,ResourceLimitError,
        "UnableToClonePackageInfo",PackageName);
      return((struct PackageInfo *) NULL);
    }
  if (info == (struct PackageInfo *) NULL)
    {
      clone_info->image_info=CloneImageInfo((ImageInfo *) NULL);
      return(clone_info);
    }
  *clone_info=(*info);
  clone_info->image_info=CloneImageInfo(info->image_info);
  return(clone_info);
}

/*
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                                                                             %
%                                                                             %
%                                                                             %
%   c o n s t a n t                                                           %
%                                                                             %
%                                                                             %
%                                                                             %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%  constant() returns a double value for the specified name.
%
%  The format of the constant routine is:
%
%      double constant(char *name,ssize_t sans)
%
%  A description of each parameter follows:
%
%    o value: Method constant returns a double value for the specified name.
%
%    o name: The name of the constant.
%
%    o sans: This integer value is not used.
%
*/
static double constant(char *name,ssize_t sans)
{
  (void) sans;
  errno=0;
  switch (*name)
  {
    case 'B':
    {
      if (strEQ(name,"BlobError"))
        return(BlobError);
      if (strEQ(name,"BlobWarning"))
        return(BlobWarning);
      break;
    }
    case 'C':
    {
      if (strEQ(name,"CacheError"))
        return(CacheError);
      if (strEQ(name,"CacheWarning"))
        return(CacheWarning);
      if (strEQ(name,"CoderError"))
        return(CoderError);
      if (strEQ(name,"CoderWarning"))
        return(CoderWarning);
      if (strEQ(name,"ConfigureError"))
        return(ConfigureError);
      if (strEQ(name,"ConfigureWarning"))
        return(ConfigureWarning);
      if (strEQ(name,"CorruptImageError"))
        return(CorruptImageError);
      if (strEQ(name,"CorruptImageWarning"))
        return(CorruptImageWarning);
      break;
    }
    case 'D':
    {
      if (strEQ(name,"DelegateError"))
        return(DelegateError);
      if (strEQ(name,"DelegateWarning"))
        return(DelegateWarning);
      if (strEQ(name,"DrawError"))
        return(DrawError);
      if (strEQ(name,"DrawWarning"))
        return(DrawWarning);
      break;
    }
    case 'E':
    {
      if (strEQ(name,"ErrorException"))
        return(ErrorException);
      if (strEQ(name,"ExceptionError"))
        return(CoderError);
      if (strEQ(name,"ExceptionWarning"))
        return(CoderWarning);
      break;
    }
    case 'F':
    {
      if (strEQ(name,"FatalErrorException"))
        return(FatalErrorException);
      if (strEQ(name,"FileOpenError"))
        return(FileOpenError);
      if (strEQ(name,"FileOpenWarning"))
        return(FileOpenWarning);
      break;
    }
    case 'I':
    {
      if (strEQ(name,"ImageError"))
        return(ImageError);
      if (strEQ(name,"ImageWarning"))
        return(ImageWarning);
      break;
    }
    case 'M':
    {
      if (strEQ(name,"MaxRGB"))
        return(QuantumRange);
      if (strEQ(name,"MissingDelegateError"))
        return(MissingDelegateError);
      if (strEQ(name,"MissingDelegateWarning"))
        return(MissingDelegateWarning);
      if (strEQ(name,"ModuleError"))
        return(ModuleError);
      if (strEQ(name,"ModuleWarning"))
        return(ModuleWarning);
      break;
    }
    case 'O':
    {
      if (strEQ(name,"Opaque"))
        return(OpaqueAlpha);
      if (strEQ(name,"OptionError"))
        return(OptionError);
      if (strEQ(name,"OptionWarning"))
        return(OptionWarning);
      break;
    }
    case 'Q':
    {
      if (strEQ(name,"MAGICKCORE_QUANTUM_DEPTH"))
        return(MAGICKCORE_QUANTUM_DEPTH);
      if (strEQ(name,"QuantumDepth"))
        return(MAGICKCORE_QUANTUM_DEPTH);
      if (strEQ(name,"QuantumRange"))
        return(QuantumRange);
      break;
    }
    case 'R':
    {
      if (strEQ(name,"ResourceLimitError"))
        return(ResourceLimitError);
      if (strEQ(name,"ResourceLimitWarning"))
        return(ResourceLimitWarning);
      if (strEQ(name,"RegistryError"))
        return(RegistryError);
      if (strEQ(name,"RegistryWarning"))
        return(RegistryWarning);
      break;
    }
    case 'S':
    {
      if (strEQ(name,"StreamError"))
        return(StreamError);
      if (strEQ(name,"StreamWarning"))
        return(StreamWarning);
      if (strEQ(name,"Success"))
        return(0);
      break;
    }
    case 'T':
    {
      if (strEQ(name,"Transparent"))
        return(TransparentAlpha);
      if (strEQ(name,"TypeError"))
        return(TypeError);
      if (strEQ(name,"TypeWarning"))
        return(TypeWarning);
      break;
    }
    case 'W':
    {
      if (strEQ(name,"WarningException"))
        return(WarningException);
      break;
    }
    case 'X':
    {
      if (strEQ(name,"XServerError"))
        return(XServerError);
      if (strEQ(name,"XServerWarning"))
        return(XServerWarning);
      break;
    }
  }
  errno=EINVAL;
  return(0);
}

/*
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                                                                             %
%                                                                             %
%                                                                             %
%   D e s t r o y P a c k a g e I n f o                                       %
%                                                                             %
%                                                                             %
%                                                                             %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%  Method DestroyPackageInfo frees a previously created info structure.
%
%  The format of the DestroyPackageInfo routine is:
%
%      DestroyPackageInfo(struct PackageInfo *info)
%
%  A description of each parameter follows:
%
%    o info: a structure of type info.
%
*/
static void DestroyPackageInfo(struct PackageInfo *info)
{
  info->image_info=DestroyImageInfo(info->image_info);
  info=(struct PackageInfo *) RelinquishMagickMemory(info);
}

/*
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                                                                             %
%                                                                             %
%                                                                             %
%   G e t L i s t                                                             %
%                                                                             %
%                                                                             %
%                                                                             %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%  Method GetList is recursively called by SetupList to traverse the
%  Image__Magick reference.  If building an reference_vector (see SetupList),
%  *current is the current position in *reference_vector and *last is the final
%  entry in *reference_vector.
%
%  The format of the GetList routine is:
%
%      GetList(info)
%
%  A description of each parameter follows:
%
%    o info: a structure of type info.
%
*/
static Image *GetList(pTHX_ SV *reference,SV ***reference_vector,
  ssize_t *current,ssize_t *last,ExceptionInfo *exception)
{
  Image
    *image;

  if (reference == (SV *) NULL)
    return(NULL);
  switch (SvTYPE(reference))
  {
    case SVt_PVAV:
    {
      AV
        *av;

      Image
        *head,
        *previous;

      ssize_t
        i,
        n;

      /*
        Array of images.
      */
      previous=(Image *) NULL;
      head=(Image *) NULL;
      av=(AV *) reference;
      n=av_len(av);
      for (i=0; i <= n; i++)
      {
        SV
          **rv;

        rv=av_fetch(av,i,0);
        if (rv && *rv && sv_isobject(*rv))
          {
            image=GetList(aTHX_ SvRV(*rv),reference_vector,current,last,
              exception);
            if (image == (Image *) NULL)
              continue;
            if (image == previous)
              {
                image=CloneImage(image,0,0,MagickTrue,exception);
                if (image == (Image *) NULL)
                  return(NULL);
              }
            image->previous=previous;
            *(previous ? &previous->next : &head)=image;
            for (previous=image; previous->next; previous=previous->next) ;
          }
      }
      return(head);
    }
    case SVt_PVMG:
    {
      /*
        Blessed scalar, one image.
      */
      image=INT2PTR(Image *,SvIV(reference));
      if (image == (Image *) NULL)
        return(NULL);
      image->previous=(Image *) NULL;
      image->next=(Image *) NULL;
      if (reference_vector)
        {
          if (*current == *last)
            {
              *last+=256;
              if (*reference_vector == (SV **) NULL)
                *reference_vector=(SV **) AcquireQuantumMemory((size_t) *last,
                  sizeof(*reference_vector));
              else
                *reference_vector=(SV **) ResizeQuantumMemory(*reference_vector,
                  (size_t) *last,sizeof(*reference_vector));
            }
          if (*reference_vector == (SV **) NULL)
            {
              ThrowPerlException(exception,ResourceLimitError,
                "MemoryAllocationFailed",PackageName);
              return((Image *) NULL);
            }
          (*reference_vector)[*current]=reference;
          (*reference_vector)[++(*current)]=NULL;
        }
      return(image);
    }
    default:
      break;
  }
  (void) fprintf(stderr,"GetList: UnrecognizedType %.20g\n",
    (double) SvTYPE(reference));
  return((Image *) NULL);
}

/*
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                                                                             %
%                                                                             %
%                                                                             %
%   G e t P a c k a g e I n f o                                               %
%                                                                             %
%                                                                             %
%                                                                             %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%  Method GetPackageInfo looks up or creates an info structure for the given
%  Image__Magick reference.  If it does create a new one, the information in
%  package_info is used to initialize it.
%
%  The format of the GetPackageInfo routine is:
%
%      struct PackageInfo *GetPackageInfo(void *reference,
%        struct PackageInfo *package_info,ExceptionInfo *exception)
%
%  A description of each parameter follows:
%
%    o info: a structure of type info.
%
%    o exception: Return any errors or warnings in this structure.
%
*/
static struct PackageInfo *GetPackageInfo(pTHX_ void *reference,
  struct PackageInfo *package_info,ExceptionInfo *exception)
{
  char
    message[MagickPathExtent];

  struct PackageInfo
    *clone_info;

  SV
    *sv;

  (void) FormatLocaleString(message,MagickPathExtent,"%s::package%s%p",
    PackageName,XS_VERSION,reference);
  sv=perl_get_sv(message,(TRUE | 0x02));
  if (sv == (SV *) NULL)
    {
      ThrowPerlException(exception,ResourceLimitError,"UnableToGetPackageInfo",
        message);
      return(package_info);
    }
  if (SvREFCNT(sv) == 0)
    (void) SvREFCNT_inc(sv);
  if (SvIOKp(sv) && (clone_info=INT2PTR(struct PackageInfo *,SvIV(sv))))
    return(clone_info);
  clone_info=ClonePackageInfo(package_info,exception);
  sv_setiv(sv,PTR2IV(clone_info));
  return(clone_info);
}

/*
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                                                                             %
%                                                                             %
%                                                                             %
%   S e t A t t r i b u t e                                                   %
%                                                                             %
%                                                                             %
%                                                                             %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%  SetAttribute() sets the attribute to the value in sval.  This can change
%  either or both of image or info.
%
%  The format of the SetAttribute routine is:
%
%      SetAttribute(struct PackageInfo *info,Image *image,char *attribute,
%        SV *sval,ExceptionInfo *exception)
%
%  A description of each parameter follows:
%
%    o list: a list of strings.
%
%    o string: a character string.
%
*/

static double SiPrefixToDoubleInterval(const char *string,const double interval)
{
  char
    *q;

  double
    value;

  value=InterpretSiPrefixValue(string,&q);
  if (*q == '%')
    value*=interval/100.0;
  return(value);
}

static inline double StringToDouble(const char *string,char **sentinel)
{
  return(InterpretLocaleValue(string,sentinel));
}

static double StringToDoubleInterval(const char *string,const double interval)
{
  char
    *q;

  double
    value;

  value=InterpretLocaleValue(string,&q);
  if (*q == '%')
    value*=interval/100.0;
  return(value);
}

static inline ssize_t StringToLong(const char *value)
{
  return(strtol(value,(char **) NULL,10));
}

static void SetAttribute(pTHX_ struct PackageInfo *info,Image *image,
  const char *attribute,SV *sval,ExceptionInfo *exception)
{
  GeometryInfo
    geometry_info;

  long
    x,
    y;

  PixelInfo
    pixel;

  MagickStatusType
    flags;

  PixelInfo
    *color,
    target_color;

  ssize_t
    sp;

  switch (*attribute)
  {
    case 'A':
    case 'a':
    {
      if (LocaleCompare(attribute,"adjoin") == 0)
        {
          sp=SvPOK(sval) ? ParseCommandOption(MagickBooleanOptions,MagickFalse,
            SvPV(sval,na)) : SvIV(sval);
          if (sp < 0)
            {
              ThrowPerlException(exception,OptionError,"UnrecognizedType",
                SvPV(sval,na));
              break;
            }
          if (info)
            info->image_info->adjoin=sp != 0 ? MagickTrue : MagickFalse;
          break;
        }
      if (LocaleCompare(attribute,"alpha") == 0)
        {
          sp=SvPOK(sval) ? ParseCommandOption(MagickAlphaChannelOptions,
            MagickFalse,SvPV(sval,na)) : SvIV(sval);
          if (sp < 0)
            {
              ThrowPerlException(exception,OptionError,"UnrecognizedType",
                SvPV(sval,na));
              break;
            }
          for ( ; image; image=image->next)
            (void) SetImageAlphaChannel(image,(AlphaChannelOption) sp,
              exception);
          break;
        }
      if (LocaleCompare(attribute,"antialias") == 0)
        {
          sp=SvPOK(sval) ? ParseCommandOption(MagickBooleanOptions,MagickFalse,
            SvPV(sval,na)) : SvIV(sval);
          if (sp < 0)
            {
              ThrowPerlException(exception,OptionError,"UnrecognizedType",
                SvPV(sval,na));
              break;
            }
          if (info)
            info->image_info->antialias=sp != 0 ? MagickTrue : MagickFalse;
          break;
        }
      if (LocaleCompare(attribute,"area-limit") == 0)
        {
          MagickSizeType
            limit;

          limit=MagickResourceInfinity;
          if (LocaleCompare(SvPV(sval,na),"unlimited") != 0)
            limit=(MagickSizeType) SiPrefixToDoubleInterval(SvPV(sval,na),
              100.0);
          (void) SetMagickResourceLimit(AreaResource,limit);
          break;
        }
      if (LocaleCompare(attribute,"attenuate") == 0)
        {
          if (info)
            (void) SetImageOption(info->image_info,attribute,SvPV(sval,na));
          break;
        }
      if (LocaleCompare(attribute,"authenticate") == 0)
        {
          if (info)
            SetImageOption(info->image_info,attribute,SvPV(sval,na));
          break;
        }
      if (info)
        SetImageOption(info->image_info,attribute,SvPV(sval,na));
      for ( ; image; image=image->next)
      {
        (void) SetImageProperty(image,attribute,SvPV(sval,na),exception);
        (void) SetImageArtifact(image,attribute,SvPV(sval,na));
      }
      break;
    }
    case 'B':
    case 'b':
    {
      if (LocaleCompare(attribute,"background") == 0)
        {
          (void) QueryColorCompliance(SvPV(sval,na),AllCompliance,&target_color,
            exception);
          if (info)
            info->image_info->background_color=target_color;
          for ( ; image; image=image->next)
            image->background_color=target_color;
          break;
        }
      if (LocaleCompare(attribute,"blue-primary") == 0)
        {
          for ( ; image; image=image->next)
          {
            flags=ParseGeometry(SvPV(sval,na),&geometry_info);
            image->chromaticity.blue_primary.x=geometry_info.rho;
            image->chromaticity.blue_primary.y=geometry_info.sigma;
            if ((flags & SigmaValue) == 0)
              image->chromaticity.blue_primary.y=
                image->chromaticity.blue_primary.x;
          }
          break;
        }
      if (LocaleCompare(attribute,"bordercolor") == 0)
        {
          (void) QueryColorCompliance(SvPV(sval,na),AllCompliance,&target_color,
            exception);
          if (info)
            info->image_info->border_color=target_color;
          for ( ; image; image=image->next)
            image->border_color=target_color;
          break;
        }
      if (info)
        SetImageOption(info->image_info,attribute,SvPV(sval,na));
      for ( ; image; image=image->next)
      {
        (void) SetImageProperty(image,attribute,SvPV(sval,na),exception);
        (void) SetImageArtifact(image,attribute,SvPV(sval,na));
      }
      break;
    }
    case 'C':
    case 'c':
    {
      if (LocaleCompare(attribute,"cache-threshold") == 0)
        {
          (void) SetMagickResourceLimit(MemoryResource,(MagickSizeType)
            SiPrefixToDoubleInterval(SvPV(sval,na),100.0));
          (void) SetMagickResourceLimit(MapResource,(MagickSizeType)
            (2.0*SiPrefixToDoubleInterval(SvPV(sval,na),100.0)));
          break;
        }
      if (LocaleCompare(attribute,"clip-mask") == 0)
        {
          Image
            *clip_mask;

          clip_mask=(Image *) NULL;
          if (SvPOK(sval))
            clip_mask=SetupList(aTHX_ SvRV(sval),&info,(SV ***) NULL,exception);
          for ( ; image; image=image->next)
            SetImageMask(image,ReadPixelMask,clip_mask,exception);
          break;
        }
      if (LocaleNCompare(attribute,"colormap",8) == 0)
        {
          for ( ; image; image=image->next)
          {
            int
              items;

            ssize_t
              i;

            if (image->storage_class == DirectClass)
              continue;
            i=0;
            items=sscanf(attribute,"%*[^[][%ld",&i);
            (void) items;
            if (i > (ssize_t) image->colors)
              i%=(ssize_t) image->colors;
            if ((strchr(SvPV(sval,na),',') == 0) ||
                (strchr(SvPV(sval,na),')') != 0))
              QueryColorCompliance(SvPV(sval,na),AllCompliance,
                image->colormap+i,exception);
            else
              {
                color=image->colormap+i;
                pixel.red=color->red;
                pixel.green=color->green;
                pixel.blue=color->blue;
                flags=ParseGeometry(SvPV(sval,na),&geometry_info);
                pixel.red=geometry_info.rho;
                pixel.green=geometry_info.sigma;
                pixel.blue=geometry_info.xi;
                color->red=ClampToQuantum(pixel.red);
                color->green=ClampToQuantum(pixel.green);
                color->blue=ClampToQuantum(pixel.blue);
              }
          }
          break;
        }
      if (LocaleCompare(attribute,"colorspace") == 0)
        {
          sp=SvPOK(sval) ? ParseCommandOption(MagickColorspaceOptions,
            MagickFalse,SvPV(sval,na)) : SvIV(sval);
          if (sp < 0)
            {
              ThrowPerlException(exception,OptionError,"UnrecognizedColorspace",
                SvPV(sval,na));
              break;
            }
          for ( ; image; image=image->next)
            (void) SetImageColorspace(image,(ColorspaceType) sp,exception);
          break;
        }
      if (LocaleCompare(attribute,"comment") == 0)
        {
          for ( ; image; image=image->next)
            (void) SetImageProperty(image,"Comment",InterpretImageProperties(
              info ? info->image_info : (ImageInfo *) NULL,image,
              SvPV(sval,na),exception),exception);
          break;
        }
      if (LocaleCompare(attribute,"compression") == 0)
        {
          sp=SvPOK(sval) ? ParseCommandOption(MagickCompressOptions,
            MagickFalse,SvPV(sval,na)) : SvIV(sval);
          if (sp < 0)
            {
              ThrowPerlException(exception,OptionError,
                "UnrecognizedImageCompression",SvPV(sval,na));
              break;
            }
          if (info)
            info->image_info->compression=(CompressionType) sp;
          for ( ; image; image=image->next)
            image->compression=(CompressionType) sp;
          break;
        }
      if (info)
        SetImageOption(info->image_info,attribute,SvPV(sval,na));
      for ( ; image; image=image->next)
      {
        (void) SetImageProperty(image,attribute,SvPV(sval,na),exception);
        (void) SetImageArtifact(image,attribute,SvPV(sval,na));
      }
      break;
    }
    case 'D':
    case 'd':
    {
      if (LocaleCompare(attribute,"debug") == 0)
        {
          SetLogEventMask(SvPV(sval,na));
          break;
        }
      if (LocaleCompare(attribute,"delay") == 0)
        {
          flags=ParseGeometry(SvPV(sval,na),&geometry_info);
          for ( ; image; image=image->next)
          {
            image->delay=(size_t) floor(geometry_info.rho+0.5);
            if ((flags & SigmaValue) != 0)
              image->ticks_per_second=(ssize_t)
                floor(geometry_info.sigma+0.5);
          }
          break;
        }
      if (LocaleCompare(attribute,"disk-limit") == 0)
        {
          MagickSizeType
            limit;

          limit=MagickResourceInfinity;
          if (LocaleCompare(SvPV(sval,na),"unlimited") != 0)
            limit=(MagickSizeType) SiPrefixToDoubleInterval(SvPV(sval,na),
              100.0);
          (void) SetMagickResourceLimit(DiskResource,limit);
          break;
        }
      if (LocaleCompare(attribute,"density") == 0)
        {
          if (IsGeometry(SvPV(sval,na)) == MagickFalse)
            {
              ThrowPerlException(exception,OptionError,"MissingGeometry",
                SvPV(sval,na));
              break;
            }
          if (info)
            (void) CloneString(&info->image_info->density,SvPV(sval,na));
          for ( ; image; image=image->next)
          {
            flags=ParseGeometry(SvPV(sval,na),&geometry_info);
            image->resolution.x=geometry_info.rho;
            image->resolution.y=geometry_info.sigma;
            if ((flags & SigmaValue) == 0)
              image->resolution.y=image->resolution.x;
          }
          break;
        }
      if (LocaleCompare(attribute,"depth") == 0)
        {
          if (info)
            info->image_info->depth=(size_t) SvIV(sval);
          for ( ; image; image=image->next)
            (void) SetImageDepth(image,(size_t) SvIV(sval),exception);
          break;
        }
      if (LocaleCompare(attribute,"dispose") == 0)
        {
          sp=SvPOK(sval) ? ParseCommandOption(MagickDisposeOptions,MagickFalse,
            SvPV(sval,na)) : SvIV(sval);
          if (sp < 0)
            {
              ThrowPerlException(exception,OptionError,
                "UnrecognizedDisposeMethod",SvPV(sval,na));
              break;
            }
          for ( ; image; image=image->next)
            image->dispose=(DisposeType) sp;
          break;
        }
      if (LocaleCompare(attribute,"dither") == 0)
        {
          if (info)
            {
              sp=SvPOK(sval) ? ParseCommandOption(MagickBooleanOptions,
                MagickFalse,SvPV(sval,na)) : SvIV(sval);
              if (sp < 0)
                {
                  ThrowPerlException(exception,OptionError,"UnrecognizedType",
                    SvPV(sval,na));
                  break;
                }
              info->image_info->dither=sp != 0 ? MagickTrue : MagickFalse;
            }
          break;
        }
      if (LocaleCompare(attribute,"display") == 0)
        {
          display:
          if (info)
            (void) CloneString(&info->image_info->server_name,SvPV(sval,na));
          break;
        }
      if (info)
        SetImageOption(info->image_info,attribute,SvPV(sval,na));
      for ( ; image; image=image->next)
      {
        (void) SetImageProperty(image,attribute,SvPV(sval,na),exception);
        (void) SetImageArtifact(image,attribute,SvPV(sval,na));
      }
      break;
    }
    case 'E':
    case 'e':
    {
      if (LocaleCompare(attribute,"endian") == 0)
        {
          sp=SvPOK(sval) ? ParseCommandOption(MagickEndianOptions,MagickFalse,
            SvPV(sval,na)) : SvIV(sval);
          if (sp < 0)
            {
              ThrowPerlException(exception,OptionError,"UnrecognizedEndianType",
                SvPV(sval,na));
              break;
            }
          if (info)
            info->image_info->endian=(EndianType) sp;
          for ( ; image; image=image->next)
            image->endian=(EndianType) sp;
          break;
        }
      if (LocaleCompare(attribute,"extract") == 0)
        {
          /*
            Set image extract geometry.
          */
          (void) CloneString(&info->image_info->extract,SvPV(sval,na));
          break;
        }
      if (info)
        SetImageOption(info->image_info,attribute,SvPV(sval,na));
      for ( ; image; image=image->next)
      {
        (void) SetImageProperty(image,attribute,SvPV(sval,na),exception);
        (void) SetImageArtifact(image,attribute,SvPV(sval,na));
      }
      break;
    }
    case 'F':
    case 'f':
    {
      if (LocaleCompare(attribute,"filename") == 0)
        {
          if (info)
            (void) CopyMagickString(info->image_info->filename,SvPV(sval,na),
              MagickPathExtent);
          for ( ; image; image=image->next)
            (void) CopyMagickString(image->filename,SvPV(sval,na),
              MagickPathExtent);
          break;
        }
      if (LocaleCompare(attribute,"file") == 0)
        {
          FILE
            *file;

          PerlIO
            *io_info;

          if (info == (struct PackageInfo *) NULL)
            break;
          io_info=IoIFP(sv_2io(sval));
          if (io_info == (PerlIO *) NULL)
            {
              ThrowPerlException(exception,BlobError,"UnableToOpenFile",
                PackageName);
              break;
            }
          file=PerlIO_findFILE(io_info);
          if (file == (FILE *) NULL)
            {
              ThrowPerlException(exception,BlobError,"UnableToOpenFile",
                PackageName);
              break;
            }
          SetImageInfoFile(info->image_info,file);
          break;
        }
      if (LocaleCompare(attribute,"fill") == 0)
        {
          if (info)
            (void) SetImageOption(info->image_info,"fill",SvPV(sval,na));
          break;
        }
      if (LocaleCompare(attribute,"font") == 0)
        {
          if (info)
            (void) CloneString(&info->image_info->font,SvPV(sval,na));
          break;
        }
      if (LocaleCompare(attribute,"foreground") == 0)
        break;
      if (LocaleCompare(attribute,"fuzz") == 0)
        {
          if (info)
            info->image_info->fuzz=StringToDoubleInterval(SvPV(sval,na),(double)
              QuantumRange+1.0);
          for ( ; image; image=image->next)
            image->fuzz=StringToDoubleInterval(SvPV(sval,na),(double)
              QuantumRange+1.0);
          break;
        }
      if (info)
        SetImageOption(info->image_info,attribute,SvPV(sval,na));
      for ( ; image; image=image->next)
      {
        (void) SetImageProperty(image,attribute,SvPV(sval,na),exception);
        (void) SetImageArtifact(image,attribute,SvPV(sval,na));
      }
      break;
    }
    case 'G':
    case 'g':
    {
      if (LocaleCompare(attribute,"gamma") == 0)
        {
          for ( ; image; image=image->next)
            image->gamma=SvNV(sval);
          break;
        }
      if (LocaleCompare(attribute,"gravity") == 0)
        {
          sp=SvPOK(sval) ? ParseCommandOption(MagickGravityOptions,MagickFalse,
            SvPV(sval,na)) : SvIV(sval);
          if (sp < 0)
            {
              ThrowPerlException(exception,OptionError,
                "UnrecognizedGravityType",SvPV(sval,na));
              break;
            }
          if (info)
            SetImageOption(info->image_info,attribute,SvPV(sval,na));
          for ( ; image; image=image->next)
            image->gravity=(GravityType) sp;
          break;
        }
      if (LocaleCompare(attribute,"green-primary") == 0)
        {
          for ( ; image; image=image->next)
          {
            flags=ParseGeometry(SvPV(sval,na),&geometry_info);
            image->chromaticity.green_primary.x=geometry_info.rho;
            image->chromaticity.green_primary.y=geometry_info.sigma;
            if ((flags & SigmaValue) == 0)
              image->chromaticity.green_primary.y=
                image->chromaticity.green_primary.x;
          }
          break;
        }
      if (info)
        SetImageOption(info->image_info,attribute,SvPV(sval,na));
      for ( ; image; image=image->next)
      {
        (void) SetImageProperty(image,attribute,SvPV(sval,na),exception);
        (void) SetImageArtifact(image,attribute,SvPV(sval,na));
      }
      break;
    }
    case 'I':
    case 'i':
    {
      if (LocaleNCompare(attribute,"index",5) == 0)
        {
          CacheView
            *image_view;

          int
            items;

          long
            index;

          Quantum
            *q;

          for ( ; image; image=image->next)
          {
            if (image->storage_class != PseudoClass)
              continue;
            x=0;
            y=0;
            items=sscanf(attribute,"%*[^[][%ld%*[,/]%ld",&x,&y);
            (void) items;
            image_view=AcquireAuthenticCacheView(image,exception);
            q=GetCacheViewAuthenticPixels(image_view,x,y,1,1,exception);
            if (q != (Quantum *) NULL)
              {
                items=sscanf(SvPV(sval,na),"%ld",&index);
                if ((index >= 0) && (index < (ssize_t) image->colors))
                  SetPixelIndex(image,index,q);
                (void) SyncCacheViewAuthenticPixels(image_view,exception);
              }
            image_view=DestroyCacheView(image_view);
          }
          break;
        }
      if (LocaleCompare(attribute,"iterations") == 0)
        {
  iterations:
          for ( ; image; image=image->next)
            image->iterations=(size_t) SvIV(sval);
          break;
        }
      if (LocaleCompare(attribute,"interlace") == 0)
        {
          sp=SvPOK(sval) ? ParseCommandOption(MagickInterlaceOptions,
            MagickFalse,SvPV(sval,na)) : SvIV(sval);
          if (sp < 0)
            {
              ThrowPerlException(exception,OptionError,
                "UnrecognizedInterlaceType",SvPV(sval,na));
              break;
            }
          if (info)
            info->image_info->interlace=(InterlaceType) sp;
          for ( ; image; image=image->next)
            image->interlace=(InterlaceType) sp;
          break;
        }
      if (info)
        SetImageOption(info->image_info,attribute,SvPV(sval,na));
      for ( ; image; image=image->next)
      {
        (void) SetImageProperty(image,attribute,SvPV(sval,na),exception);
        (void) SetImageArtifact(image,attribute,SvPV(sval,na));
      }
      break;
    }
    case 'L':
    case 'l':
    {
      if (LocaleCompare(attribute,"label") == 0)
        {
          for ( ; image; image=image->next)
            (void) SetImageProperty(image,"label",InterpretImageProperties(
              info ? info->image_info : (ImageInfo *) NULL,image,
              SvPV(sval,na),exception),exception);
          break;
        }
      if (LocaleCompare(attribute,"loop") == 0)
        goto iterations;
      if (info)
        SetImageOption(info->image_info,attribute,SvPV(sval,na));
      for ( ; image; image=image->next)
      {
        (void) SetImageProperty(image,attribute,SvPV(sval,na),exception);
        (void) SetImageArtifact(image,attribute,SvPV(sval,na));
      }
      break;
    }
    case 'M':
    case 'm':
    {
      if (LocaleCompare(attribute,"magick") == 0)
        {
          if (info)
            (void) FormatLocaleString(info->image_info->filename,
              MagickPathExtent,"%s:",SvPV(sval,na));
          for ( ; image; image=image->next)
            (void) CopyMagickString(image->magick,SvPV(sval,na),
              MagickPathExtent);
          break;
        }
      if (LocaleCompare(attribute,"map-limit") == 0)
        {
          MagickSizeType
            limit;

          limit=MagickResourceInfinity;
          if (LocaleCompare(SvPV(sval,na),"unlimited") != 0)
            limit=(MagickSizeType) SiPrefixToDoubleInterval(SvPV(sval,na),
              100.0);
          (void) SetMagickResourceLimit(MapResource,limit);
          break;
        }
      if (LocaleCompare(attribute,"mask") == 0)
        {
          Image
            *mask;

          mask=(Image *) NULL;
          if (SvPOK(sval))
            mask=SetupList(aTHX_ SvRV(sval),&info,(SV ***) NULL,exception);
          for ( ; image; image=image->next)
            SetImageMask(image,ReadPixelMask,mask,exception);
          break;
        }
      if (LocaleCompare(attribute,"mattecolor") == 0)
        {
          (void) QueryColorCompliance(SvPV(sval,na),AllCompliance,&target_color,
            exception);
          if (info)
            info->image_info->alpha_color=target_color;
          for ( ; image; image=image->next)
            image->alpha_color=target_color;
          break;
        }
      if (LocaleCompare(attribute,"matte") == 0)
        {
          sp=SvPOK(sval) ? ParseCommandOption(MagickBooleanOptions,MagickFalse,
            SvPV(sval,na)) : SvIV(sval);
          if (sp < 0)
            {
              ThrowPerlException(exception,OptionError,"UnrecognizedType",
                SvPV(sval,na));
              break;
            }
          for ( ; image; image=image->next)
            image->alpha_trait=sp != 0 ? BlendPixelTrait : UndefinedPixelTrait;
          break;
        }
      if (LocaleCompare(attribute,"memory-limit") == 0)
        {
          MagickSizeType
            limit;

          limit=MagickResourceInfinity;
          if (LocaleCompare(SvPV(sval,na),"unlimited") != 0)
            limit=(MagickSizeType) SiPrefixToDoubleInterval(SvPV(sval,na),
              100.0);
          (void) SetMagickResourceLimit(MemoryResource,limit);
          break;
        }
      if (LocaleCompare(attribute,"monochrome") == 0)
        {
          sp=SvPOK(sval) ? ParseCommandOption(MagickBooleanOptions,MagickFalse,
            SvPV(sval,na)) : SvIV(sval);
          if (sp < 0)
            {
              ThrowPerlException(exception,OptionError,"UnrecognizedType",
                SvPV(sval,na));
              break;
            }
          if (info)
            info->image_info->monochrome=sp != 0 ? MagickTrue : MagickFalse;
          for ( ; image; image=image->next)
            (void) SetImageType(image,BilevelType,exception);
          break;
        }
      if (info)
        SetImageOption(info->image_info,attribute,SvPV(sval,na));
      for ( ; image; image=image->next)
      {
        (void) SetImageProperty(image,attribute,SvPV(sval,na),exception);
        (void) SetImageArtifact(image,attribute,SvPV(sval,na));
      }
      break;
    }
    case 'O':
    case 'o':
    {
      if (LocaleCompare(attribute,"option") == 0)
        {
          if (info)
            DefineImageOption(info->image_info,SvPV(sval,na));
          break;
        }
      if (LocaleCompare(attribute,"orientation") == 0)
        {
          sp=SvPOK(sval) ? ParseCommandOption(MagickOrientationOptions,
            MagickFalse,SvPV(sval,na)) : SvIV(sval);
          if (sp < 0)
            {
              ThrowPerlException(exception,OptionError,
                "UnrecognizedOrientationType",SvPV(sval,na));
              break;
            }
          if (info)
            info->image_info->orientation=(OrientationType) sp;
          for ( ; image; image=image->next)
            image->orientation=(OrientationType) sp;
          break;
        }
      if (info)
        SetImageOption(info->image_info,attribute,SvPV(sval,na));
      for ( ; image; image=image->next)
      {
        (void) SetImageProperty(image,attribute,SvPV(sval,na),exception);
        (void) SetImageArtifact(image,attribute,SvPV(sval,na));
      }
      break;
    }
    case 'P':
    case 'p':
    {
      if (LocaleCompare(attribute,"page") == 0)
        {
          char
            *geometry;

          geometry=GetPageGeometry(SvPV(sval,na));
          if (info)
            (void) CloneString(&info->image_info->page,geometry);
          for ( ; image; image=image->next)
            (void) ParsePageGeometry(image,geometry,&image->page,exception);
          geometry=(char *) RelinquishMagickMemory(geometry);
          break;
        }
      if (LocaleNCompare(attribute,"pixel",5) == 0)
        {
          CacheView
            *image_view;

          int
            items;

          PixelInfo
            pixel;

          Quantum
            *q;

          for ( ; image; image=image->next)
          {
            if (SetImageStorageClass(image,DirectClass,exception) == MagickFalse)
              break;
            x=0;
            y=0;
            items=sscanf(attribute,"%*[^[][%ld%*[,/]%ld",&x,&y);
            (void) items;
            image_view=AcquireVirtualCacheView(image,exception);
            q=GetCacheViewAuthenticPixels(image_view,x,y,1,1,exception);
            if (q != (Quantum *) NULL)
              {
                if ((strchr(SvPV(sval,na),',') == 0) ||
                    (strchr(SvPV(sval,na),')') != 0))
                  QueryColorCompliance(SvPV(sval,na),AllCompliance,
                    &pixel,exception);
                else
                  {
                    GetPixelInfo(image,&pixel);
                    flags=ParseGeometry(SvPV(sval,na),&geometry_info);
                    pixel.red=geometry_info.rho;
                    if ((flags & SigmaValue) != 0)
                      pixel.green=geometry_info.sigma;
                    if ((flags & XiValue) != 0)
                      pixel.blue=geometry_info.xi;
                    if ((flags & PsiValue) != 0)
                      pixel.alpha=geometry_info.psi;
                    if ((flags & ChiValue) != 0)
                      pixel.black=geometry_info.chi;
                  }
                SetPixelRed(image,ClampToQuantum(pixel.red),q);
                SetPixelGreen(image,ClampToQuantum(pixel.green),q);
                SetPixelBlue(image,ClampToQuantum(pixel.blue),q);
                if (image->colorspace == CMYKColorspace)
                  SetPixelBlack(image,ClampToQuantum(pixel.black),q);
                SetPixelAlpha(image,ClampToQuantum(pixel.alpha),q);
                (void) SyncCacheViewAuthenticPixels(image_view,exception);
              }
            image_view=DestroyCacheView(image_view);
          }
          break;
        }
      if (LocaleCompare(attribute,"pointsize") == 0)
        {
          if (info)
            {
              (void) ParseGeometry(SvPV(sval,na),&geometry_info);
              info->image_info->pointsize=geometry_info.rho;
            }
          break;
        }
      if (LocaleCompare(attribute,"precision") == 0)
        {
          (void) SetMagickPrecision(SvIV(sval));
          break;
        }
      if (info)
        SetImageOption(info->image_info,attribute,SvPV(sval,na));
      for ( ; image; image=image->next)
      {
        (void) SetImageProperty(image,attribute,SvPV(sval,na),exception);
        (void) SetImageArtifact(image,attribute,SvPV(sval,na));
      }
      break;
    }
    case 'Q':
    case 'q':
    {
      if (LocaleCompare(attribute,"quality") == 0)
        {
          if (info)
            info->image_info->quality=(size_t) SvIV(sval);
          for ( ; image; image=image->next)
            image->quality=(size_t) SvIV(sval);
          break;
        }
      if (info)
        SetImageOption(info->image_info,attribute,SvPV(sval,na));
      for ( ; image; image=image->next)
      {
        (void) SetImageProperty(image,attribute,SvPV(sval,na),exception);
        (void) SetImageArtifact(image,attribute,SvPV(sval,na));
      }
      break;
    }
    case 'R':
    case 'r':
    {
      if (LocaleCompare(attribute,"read-mask") == 0)
        {
          Image
            *mask;

          mask=(Image *) NULL;
          if (SvPOK(sval))
            mask=SetupList(aTHX_ SvRV(sval),&info,(SV ***) NULL,exception);
          for ( ; image; image=image->next)
            SetImageMask(image,ReadPixelMask,mask,exception);
          break;
        }
      if (LocaleCompare(attribute,"red-primary") == 0)
        {
          for ( ; image; image=image->next)
          {
            flags=ParseGeometry(SvPV(sval,na),&geometry_info);
            image->chromaticity.red_primary.x=geometry_info.rho;
            image->chromaticity.red_primary.y=geometry_info.sigma;
            if ((flags & SigmaValue) == 0)
              image->chromaticity.red_primary.y=
                image->chromaticity.red_primary.x;
          }
          break;
        }
      if (LocaleNCompare(attribute,"registry:",9) == 0)
        {
          (void) SetImageRegistry(StringRegistryType,attribute+9,SvPV(sval,na),
            exception);
          break;
        }
      if (LocaleCompare(attribute,"render") == 0)
        {
          sp=SvPOK(sval) ? ParseCommandOption(MagickIntentOptions,MagickFalse,
            SvPV(sval,na)) : SvIV(sval);
          if (sp < 0)
            {
              ThrowPerlException(exception,OptionError,"UnrecognizedIntentType",
                SvPV(sval,na));
              break;
            }
         for ( ; image; image=image->next)
           image->rendering_intent=(RenderingIntent) sp;
         break;
       }
      if (LocaleCompare(attribute,"repage") == 0)
        {
          RectangleInfo
            geometry;

          for ( ; image; image=image->next)
          {
            flags=ParseAbsoluteGeometry(SvPV(sval,na),&geometry);
            if ((flags & WidthValue) != 0)
              {
                if ((flags & HeightValue) == 0)
                  geometry.height=geometry.width;
                image->page.width=geometry.width;
                image->page.height=geometry.height;
              }
            if ((flags & AspectValue) != 0)
              {
                if ((flags & XValue) != 0)
                  image->page.x+=geometry.x;
                if ((flags & YValue) != 0)
                  image->page.y+=geometry.y;
              }
            else
              {
                if ((flags & XValue) != 0)
                  {
                    image->page.x=geometry.x;
                    if (((flags & WidthValue) != 0) && (geometry.x > 0))
                      image->page.width=(size_t) ((ssize_t) image->columns+
                        geometry.x);
                  }
                if ((flags & YValue) != 0)
                  {
                    image->page.y=geometry.y;
                    if (((flags & HeightValue) != 0) && (geometry.y > 0))
                      image->page.height=(size_t) ((ssize_t) image->rows+
                        geometry.y);
                  }
              }
          }
          break;
        }
      if (info)
        SetImageOption(info->image_info,attribute,SvPV(sval,na));
      for ( ; image; image=image->next)
      {
        (void) SetImageProperty(image,attribute,SvPV(sval,na),exception);
        (void) SetImageArtifact(image,attribute,SvPV(sval,na));
      }
      break;
    }
    case 'S':
    case 's':
    {
      if (LocaleCompare(attribute,"sampling-factor") == 0)
        {
          if (IsGeometry(SvPV(sval,na)) == MagickFalse)
            {
              ThrowPerlException(exception,OptionError,"MissingGeometry",
                SvPV(sval,na));
              break;
            }
          if (info)
            (void) CloneString(&info->image_info->sampling_factor,
              SvPV(sval,na));
          break;
        }
      if (LocaleCompare(attribute,"scene") == 0)
        {
          for ( ; image; image=image->next)
            image->scene=(size_t) SvIV(sval);
          break;
        }
      if (LocaleCompare(attribute,"server") == 0)
        goto display;
      if (LocaleCompare(attribute,"size") == 0)
        {
          if (info)
            {
              if (IsGeometry(SvPV(sval,na)) == MagickFalse)
                {
                  ThrowPerlException(exception,OptionError,"MissingGeometry",
                    SvPV(sval,na));
                  break;
                }
              (void) CloneString(&info->image_info->size,SvPV(sval,na));
            }
          break;
        }
      if (LocaleCompare(attribute,"stroke") == 0)
        {
          if (info)
            (void) SetImageOption(info->image_info,"stroke",SvPV(sval,na));
          break;
        }
      if (info)
        SetImageOption(info->image_info,attribute,SvPV(sval,na));
      for ( ; image; image=image->next)
      {
        (void) SetImageProperty(image,attribute,SvPV(sval,na),exception);
        (void) SetImageArtifact(image,attribute,SvPV(sval,na));
      }
      break;
    }
    case 'T':
    case 't':
    {
      if (LocaleCompare(attribute,"texture") == 0)
        {
          if (info)
            (void) CloneString(&info->image_info->texture,SvPV(sval,na));
          break;
        }
      if (LocaleCompare(attribute,"thread-limit") == 0)
        {
          MagickSizeType
            limit;

          limit=MagickResourceInfinity;
          if (LocaleCompare(SvPV(sval,na),"unlimited") != 0)
            limit=(MagickSizeType) SiPrefixToDoubleInterval(SvPV(sval,na),
              100.0);
          (void) SetMagickResourceLimit(ThreadResource,limit);
          break;
        }
      if (LocaleCompare(attribute,"tile-offset") == 0)
        {
          char
            *geometry;

          geometry=GetPageGeometry(SvPV(sval,na));
          if (info)
            (void) CloneString(&info->image_info->page,geometry);
          for ( ; image; image=image->next)
            (void) ParsePageGeometry(image,geometry,&image->tile_offset,
              exception);
          geometry=(char *) RelinquishMagickMemory(geometry);
          break;
        }
      if (LocaleCompare(attribute,"time-limit") == 0)
        {
          MagickSizeType
            limit;

          limit=MagickResourceInfinity;
          if (LocaleCompare(SvPV(sval,na),"unlimited") != 0)
            limit=(MagickSizeType) SiPrefixToDoubleInterval(SvPV(sval,na),
              100.0);
          (void) SetMagickResourceLimit(TimeResource,limit);
          break;
        }
      if (LocaleCompare(attribute,"transparent-color") == 0)
        {
          (void) QueryColorCompliance(SvPV(sval,na),AllCompliance,&target_color,
            exception);
          if (info)
            info->image_info->transparent_color=target_color;
          for ( ; image; image=image->next)
            image->transparent_color=target_color;
          break;
        }
      if (LocaleCompare(attribute,"type") == 0)
        {
          sp=SvPOK(sval) ? ParseCommandOption(MagickTypeOptions,MagickFalse,
            SvPV(sval,na)) : SvIV(sval);
          if (sp < 0)
            {
              ThrowPerlException(exception,OptionError,"UnrecognizedType",
                SvPV(sval,na));
              break;
            }
          if (info)
            info->image_info->type=(ImageType) sp;
          for ( ; image; image=image->next)
            SetImageType(image,(ImageType) sp,exception);
          break;
        }
      if (info)
        SetImageOption(info->image_info,attribute,SvPV(sval,na));
      for ( ; image; image=image->next)
      {
        (void) SetImageProperty(image,attribute,SvPV(sval,na),exception);
        (void) SetImageArtifact(image,attribute,SvPV(sval,na));
      }
      break;
    }
    case 'U':
    case 'u':
    {
      if (LocaleCompare(attribute,"units") == 0)
        {
          sp=SvPOK(sval) ? ParseCommandOption(MagickResolutionOptions,
            MagickFalse,SvPV(sval,na)) : SvIV(sval);
          if (sp < 0)
            {
              ThrowPerlException(exception,OptionError,"UnrecognizedUnitsType",
                SvPV(sval,na));
              break;
            }
          if (info)
            info->image_info->units=(ResolutionType) sp;
          for ( ; image; image=image->next)
          {
            ResolutionType
              units;

            units=(ResolutionType) sp;
            if (image->units != units)
              switch (image->units)
              {
                case UndefinedResolution:
                case PixelsPerInchResolution:
                {
                  if (units == PixelsPerCentimeterResolution)
                    {
                      image->resolution.x*=2.54;
                      image->resolution.y*=2.54;
                    }
                  break;
                }
                case PixelsPerCentimeterResolution:
                {
                  if (units == PixelsPerInchResolution)
                    {
                      image->resolution.x/=2.54;
                      image->resolution.y/=2.54;
                    }
                  break;
                }
              }
            image->units=units;
          }
          break;
        }
      if (info)
        SetImageOption(info->image_info,attribute,SvPV(sval,na));
      for ( ; image; image=image->next)
      {
        (void) SetImageProperty(image,attribute,SvPV(sval,na),exception);
        (void) SetImageArtifact(image,attribute,SvPV(sval,na));
      }
      break;
    }
    case 'V':
    case 'v':
    {
      if (LocaleCompare(attribute,"verbose") == 0)
        {
          sp=SvPOK(sval) ? ParseCommandOption(MagickBooleanOptions,MagickFalse,
            SvPV(sval,na)) : SvIV(sval);
          if (sp < 0)
            {
              ThrowPerlException(exception,OptionError,"UnrecognizedType",
                SvPV(sval,na));
              break;
            }
          if (info)
            info->image_info->verbose=sp != 0 ? MagickTrue : MagickFalse;
          break;
        }
      if (LocaleCompare(attribute,"virtual-pixel") == 0)
        {
          sp=SvPOK(sval) ? ParseCommandOption(MagickVirtualPixelOptions,
            MagickFalse,SvPV(sval,na)) : SvIV(sval);
          if (sp < 0)
            {
              ThrowPerlException(exception,OptionError,
                "UnrecognizedVirtualPixelMethod",SvPV(sval,na));
              break;
            }
          for ( ; image; image=image->next)
            SetImageVirtualPixelMethod(image,(VirtualPixelMethod) sp,exception);
          break;
        }
      if (info)
        SetImageOption(info->image_info,attribute,SvPV(sval,na));
      for ( ; image; image=image->next)
      {
        (void) SetImageProperty(image,attribute,SvPV(sval,na),exception);
        (void) SetImageArtifact(image,attribute,SvPV(sval,na));
      }
      break;
    }
    case 'W':
    case 'w':
    {
      if (LocaleCompare(attribute,"white-point") == 0)
        {
          for ( ; image; image=image->next)
          {
            flags=ParseGeometry(SvPV(sval,na),&geometry_info);
            image->chromaticity.white_point.x=geometry_info.rho;
            image->chromaticity.white_point.y=geometry_info.sigma;
            if ((flags & SigmaValue) == 0)
              image->chromaticity.white_point.y=
                image->chromaticity.white_point.x;
          }
          break;
        }
      if (LocaleCompare(attribute,"write-mask") == 0)
        {
          Image
            *mask;

          mask=(Image *) NULL;
          if (SvPOK(sval))
            mask=SetupList(aTHX_ SvRV(sval),&info,(SV ***) NULL,exception);
          for ( ; image; image=image->next)
            SetImageMask(image,WritePixelMask,mask,exception);
          break;
        }
      if (info)
        SetImageOption(info->image_info,attribute,SvPV(sval,na));
      for ( ; image; image=image->next)
      {
        (void) SetImageProperty(image,attribute,SvPV(sval,na),exception);
        (void) SetImageArtifact(image,attribute,SvPV(sval,na));
      }
      break;
    }
    default:
    {
      if (info)
        SetImageOption(info->image_info,attribute,SvPV(sval,na));
      for ( ; image; image=image->next)
      {
        (void) SetImageProperty(image,attribute,SvPV(sval,na),exception);
        (void) SetImageArtifact(image,attribute,SvPV(sval,na));
      }
      break;
    }
  }
}

/*
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                                                                             %
%                                                                             %
%                                                                             %
%   S e t u p L i s t                                                         %
%                                                                             %
%                                                                             %
%                                                                             %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%  Method SetupList returns the list of all the images linked by their
%  image->next and image->previous link lists for use with ImageMagick.  If
%  info is non-NULL, an info structure is returned in *info.  If
%  reference_vector is non-NULL,an array of SV* are returned in
%  *reference_vector.  Reference_vector is used when the images are going to be
%  replaced with new Image*'s.
%
%  The format of the SetupList routine is:
%
%      Image *SetupList(SV *reference,struct PackageInfo **info,
%        SV ***reference_vector,ExceptionInfo *exception)
%
%  A description of each parameter follows:
%
%    o list: a list of strings.
%
%    o string: a character string.
%
%    o exception: Return any errors or warnings in this structure.
%
*/
static Image *SetupList(pTHX_ SV *reference,struct PackageInfo **info,
  SV ***reference_vector,ExceptionInfo *exception)
{
  Image
    *image;

  ssize_t
    current,
    last;

  if (reference_vector)
    *reference_vector=NULL;
  if (info)
    *info=NULL;
  current=0;
  last=0;
  image=GetList(aTHX_ reference,reference_vector,&current,&last,exception);
  if (info && (SvTYPE(reference) == SVt_PVAV))
    *info=GetPackageInfo(aTHX_ (void *) reference,(struct PackageInfo *) NULL,
      exception);
  return(image);
}

/*
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                                                                             %
%                                                                             %
%                                                                             %
%   s t r E Q c a s e                                                         %
%                                                                             %
%                                                                             %
%                                                                             %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%  strEQcase() compares two strings and returns 0 if they are the
%  same or if the second string runs out first.  The comparison is case
%  insensitive.
%
%  The format of the strEQcase routine is:
%
%      ssize_t strEQcase(const char *p,const char *q)
%
%  A description of each parameter follows:
%
%    o p: a character string.
%
%    o q: a character string.
%
%
*/
static ssize_t strEQcase(const char *p,const char *q)
{
  char
    c;

  ssize_t
    i;

  for (i=0 ; (c=(*q)) != 0; i++)
  {
    if ((isUPPER((unsigned char) c) ? toLOWER(c) : c) !=
        (isUPPER((unsigned char) *p) ? toLOWER(*p) : *p))
      return(0);
    p++;
    q++;
  }
  return(((*q == 0) && (*p == 0)) ? i : 0);
}

/*
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                                                                             %
%                                                                             %
%                                                                             %
%   I m a g e : : M a g i c k                                                 %
%                                                                             %
%                                                                             %
%                                                                             %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%
*/
MODULE = Image::Magick PACKAGE = Image::Magick

PROTOTYPES: ENABLE

BOOT:
  MagickCoreGenesis("PerlMagick",MagickFalse);
  SetWarningHandler(NULL);
  SetErrorHandler(NULL);
  magick_registry=NewSplayTree((int (*)(const void *,const void *))
    NULL,(void *(*)(void *)) NULL,(void *(*)(void *)) NULL);

void
UNLOAD()
  PPCODE:
  {
    if (magick_registry != (SplayTreeInfo *) NULL)
      magick_registry=DestroySplayTree(magick_registry);
    MagickCoreTerminus();
  }

double
constant(name,argument)
  char *name
  ssize_t argument

#
###############################################################################
#                                                                             #
#                                                                             #
#                                                                             #
#   A n i m a t e                                                             #
#                                                                             #
#                                                                             #
#                                                                             #
###############################################################################
#
#
void
Animate(ref,...)
  Image::Magick ref=NO_INIT
  ALIAS:
    AnimateImage  = 1
    animate       = 2
    animateimage  = 3
  PPCODE:
  {
    ExceptionInfo
      *exception;

    Image
      *image;

    ssize_t
      i;

    struct PackageInfo
      *info,
      *package_info;

    SV
      *perl_exception,
      *reference;

    PERL_UNUSED_VAR(ref);
    PERL_UNUSED_VAR(ix);
    exception=AcquireExceptionInfo();
    perl_exception=newSVpv("",0);
    package_info=(struct PackageInfo *) NULL;
    if (sv_isobject(ST(0)) == 0)
      {
        ThrowPerlException(exception,OptionError,"ReferenceIsNotMyType",
          PackageName);
        goto PerlException;
      }
    reference=SvRV(ST(0));
    image=SetupList(aTHX_ reference,&info,(SV ***) NULL,exception);
    if (image == (Image *) NULL)
      {
        ThrowPerlException(exception,OptionError,"NoImagesDefined",
          PackageName);
        goto PerlException;
      }
    package_info=ClonePackageInfo(info,exception);
    if (items == 2)
      SetAttribute(aTHX_ package_info,NULL,"server",ST(1),exception);
    else
      if (items > 2)
        for (i=2; i < items; i+=2)
          SetAttribute(aTHX_ package_info,image,SvPV(ST(i-1),na),ST(i),
            exception);
    (void) AnimateImages(package_info->image_info,image,exception);
    (void) CatchImageException(image);

  PerlException:
    if (package_info != (struct PackageInfo *) NULL)
      DestroyPackageInfo(package_info);
    InheritPerlException(exception,perl_exception);
    exception=DestroyExceptionInfo(exception);
    sv_setiv(perl_exception,(IV) SvCUR(perl_exception) != 0);
    SvPOK_on(perl_exception);
    ST(0)=sv_2mortal(perl_exception);
    XSRETURN(1);
  }

#
###############################################################################
#                                                                             #
#                                                                             #
#                                                                             #
#   A p p e n d                                                               #
#                                                                             #
#                                                                             #
#                                                                             #
###############################################################################
#
#
void
Append(ref,...)
  Image::Magick ref=NO_INIT
  ALIAS:
    AppendImage  = 1
    append       = 2
    appendimage  = 3
  PPCODE:
  {
    AV
      *av;

    char
      *attribute;

    ExceptionInfo
      *exception;

    HV
      *hv;

    Image
      *image;

    ssize_t
      i,
      stack;

    struct PackageInfo
      *info;

    SV
      *av_reference,
      *perl_exception,
      *reference,
      *rv,
      *sv;

    PERL_UNUSED_VAR(ref);
    PERL_UNUSED_VAR(ix);
    exception=AcquireExceptionInfo();
    perl_exception=newSVpv("",0);
    sv=NULL;
    attribute=NULL;
    av=NULL;
    if (sv_isobject(ST(0)) == 0)
      {
        ThrowPerlException(exception,OptionError,"ReferenceIsNotMyType",
          PackageName);
        goto PerlException;
      }
    reference=SvRV(ST(0));
    hv=SvSTASH(reference);
    av=newAV();
    av_reference=sv_2mortal(sv_bless(newRV((SV *) av),hv));
    SvREFCNT_dec(av);
    image=SetupList(aTHX_ reference,&info,(SV ***) NULL,exception);
    if (image == (Image *) NULL)
      {
        ThrowPerlException(exception,OptionError,"NoImagesDefined",
          PackageName);
        goto PerlException;
      }
    info=GetPackageInfo(aTHX_ (void *) av,info,exception);
    /*
      Get options.
    */
    stack=MagickTrue;
    for (i=2; i < items; i+=2)
    {
      attribute=(char *) SvPV(ST(i-1),na);
      switch (*attribute)
      {
        case 'S':
        case 's':
        {
          if (LocaleCompare(attribute,"stack") == 0)
            {
              stack=ParseCommandOption(MagickBooleanOptions,MagickFalse,
                SvPV(ST(i),na));
              if (stack < 0)
                {
                  ThrowPerlException(exception,OptionError,"UnrecognizedType",
                    SvPV(ST(i),na));
                  return;
                }
              break;
            }
          ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
            attribute);
          break;
        }
        default:
        {
          ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
            attribute);
          break;
        }
      }
    }
    image=AppendImages(image,stack != 0 ? MagickTrue : MagickFalse,exception);
    if (image == (Image *) NULL)
      goto PerlException;
    for ( ; image; image=image->next)
    {
      AddImageToRegistry(sv,image);
      rv=newRV(sv);
      av_push(av,sv_bless(rv,hv));
      SvREFCNT_dec(sv);
    }
    exception=DestroyExceptionInfo(exception);
    ST(0)=av_reference;
    SvREFCNT_dec(perl_exception);
    XSRETURN(1);

  PerlException:
    InheritPerlException(exception,perl_exception);
    exception=DestroyExceptionInfo(exception);
    sv_setiv(perl_exception,(IV) SvCUR(perl_exception) != 0);
    SvPOK_on(perl_exception);
    ST(0)=sv_2mortal(perl_exception);
    XSRETURN(1);
  }

#
###############################################################################
#                                                                             #
#                                                                             #
#                                                                             #
#   A v e r a g e                                                             #
#                                                                             #
#                                                                             #
#                                                                             #
###############################################################################
#
#
void
Average(ref)
  Image::Magick ref=NO_INIT
  ALIAS:
    AverageImage   = 1
    average        = 2
    averageimage   = 3
  PPCODE:
  {
    AV
      *av;

    char
      *p;

    ExceptionInfo
      *exception;

    HV
      *hv;

    Image
      *image;

    struct PackageInfo
      *info;

    SV
      *perl_exception,
      *reference,
      *rv,
      *sv;

    PERL_UNUSED_VAR(ref);
    PERL_UNUSED_VAR(ix);
    exception=AcquireExceptionInfo();
    perl_exception=newSVpv("",0);
    sv=NULL;
    if (sv_isobject(ST(0)) == 0)
      {
        ThrowPerlException(exception,OptionError,"ReferenceIsNotMyType",
          PackageName);
        goto PerlException;
      }
    reference=SvRV(ST(0));
    hv=SvSTASH(reference);
    image=SetupList(aTHX_ reference,&info,(SV ***) NULL,exception);
    if (image == (Image *) NULL)
      {
        ThrowPerlException(exception,OptionError,"NoImagesDefined",
          PackageName);
        goto PerlException;
      }
    image=EvaluateImages(image,MeanEvaluateOperator,exception);
    if (image == (Image *) NULL)
      goto PerlException;
    /*
      Create blessed Perl array for the returned image.
    */
    av=newAV();
    ST(0)=sv_2mortal(sv_bless(newRV((SV *) av),hv));
    SvREFCNT_dec(av);
    AddImageToRegistry(sv,image);
    rv=newRV(sv);
    av_push(av,sv_bless(rv,hv));
    SvREFCNT_dec(sv);
    info=GetPackageInfo(aTHX_ (void *) av,info,exception);
    (void) FormatLocaleString(info->image_info->filename,MagickPathExtent,
      "average-%.*s",(int) (MagickPathExtent-9),
      ((p=strrchr(image->filename,'/')) ? p+1 : image->filename));
    (void) CopyMagickString(image->filename,info->image_info->filename,
      MagickPathExtent);
    SetImageInfo(info->image_info,0,exception);
    exception=DestroyExceptionInfo(exception);
    SvREFCNT_dec(perl_exception);
    XSRETURN(1);

  PerlException:
    InheritPerlException(exception,perl_exception);
    exception=DestroyExceptionInfo(exception);
    sv_setiv(perl_exception,(IV) SvCUR(perl_exception) != 0);
    SvPOK_on(perl_exception);
    ST(0)=sv_2mortal(perl_exception);
    XSRETURN(1);
  }

#
###############################################################################
#                                                                             #
#                                                                             #
#                                                                             #
#   B l o b T o I m a g e                                                     #
#                                                                             #
#                                                                             #
#                                                                             #
###############################################################################
#
#
void
BlobToImage(ref,...)
  Image::Magick ref=NO_INIT
  ALIAS:
    BlobToImage  = 1
    blobtoimage  = 2
    blobto       = 3
  PPCODE:
  {
    AV
      *av;

    char
      **keep,
      **list,
      **p;

    ExceptionInfo
      *exception;

    HV
      *hv;

    Image
      *image;

    ssize_t
      ac,
      i,
      n,
      number_images;

    STRLEN
      *length;

    struct PackageInfo
      *info;

    SV
      *perl_exception,
      *reference,
      *rv,
      *sv;

    PERL_UNUSED_VAR(ref);
    PERL_UNUSED_VAR(ix);
    exception=AcquireExceptionInfo();
    perl_exception=newSVpv("",0);
    sv=NULL;
    number_images=0;
    ac=(items < 2) ? 1 : items-1;
    length=(STRLEN *) NULL;
    list=(char **) AcquireQuantumMemory((size_t) ac+1UL,sizeof(*list));
    if (list == (char **) NULL)
      {
        ThrowPerlException(exception,ResourceLimitError,
          "MemoryAllocationFailed",PackageName);
        goto PerlException;
      }
    length=(STRLEN *) AcquireQuantumMemory((size_t) ac+1UL,sizeof(*length));
    if (length == (STRLEN *) NULL)
      {
        ThrowPerlException(exception,ResourceLimitError,
          "MemoryAllocationFailed",PackageName);
        goto PerlException;
      }
    if (sv_isobject(ST(0)) == 0)
      {
        ThrowPerlException(exception,OptionError,"ReferenceIsNotMyType",
          PackageName);
        goto PerlException;
      }
    reference=SvRV(ST(0));
    hv=SvSTASH(reference);
    if (SvTYPE(reference) != SVt_PVAV)
      {
        ThrowPerlException(exception,OptionError,"ReferenceIsNotMyType",
          PackageName);
        goto PerlException;
      }
    av=(AV *) reference;
    info=GetPackageInfo(aTHX_ (void *) av,(struct PackageInfo *) NULL,
      exception);
    n=1;
    if (items <= 1)
      {
        ThrowPerlException(exception,OptionError,"NoBlobDefined",PackageName);
        goto PerlException;
      }
    for (n=0, i=0; i < ac; i++)
    {
      list[n]=(char *) (SvPV(ST(i+1),length[n]));
      if ((items >= 3) && strEQcase((char *) SvPV(ST(i+1),na),"blob"))
        {
          list[n]=(char *) (SvPV(ST(i+2),length[n]));
          continue;
        }
      n++;
    }
    list[n]=(char *) NULL;
    keep=list;
    for (i=number_images=0; i < n; i++)
    {
      image=BlobToImage(info->image_info,list[i],length[i],exception);
      if (image == (Image *) NULL)
        break;
      for ( ; image; image=image->next)
      {
        AddImageToRegistry(sv,image);
        rv=newRV(sv);
        av_push(av,sv_bless(rv,hv));
        SvREFCNT_dec(sv);
        number_images++;
      }
    }
    /*
      Free resources.
    */
    for (i=0; i < n; i++)
      if (list[i] != (char *) NULL)
        for (p=keep; list[i] != *p++; )
          if (*p == (char *) NULL)
            {
              list[i]=(char *) RelinquishMagickMemory(list[i]);
              break;
            }

  PerlException:
    if (list)
      list=(char **) RelinquishMagickMemory(list);
    if (length)
      length=(STRLEN *) RelinquishMagickMemory(length);
    InheritPerlException(exception,perl_exception);
    exception=DestroyExceptionInfo(exception);
    sv_setiv(perl_exception,(IV) number_images);
    SvPOK_on(perl_exception);
    ST(0)=sv_2mortal(perl_exception);
    XSRETURN(1);
  }

#
###############################################################################
#                                                                             #
#                                                                             #
#                                                                             #
#   C h a n n e l F x                                                         #
#                                                                             #
#                                                                             #
#                                                                             #
###############################################################################
#
#
void
ChannelFx(ref,...)
  Image::Magick ref=NO_INIT
  ALIAS:
    ChannelFxImage  = 1
    channelfx       = 2
    channelfximage  = 3
  PPCODE:
  {
    AV
      *av;

    char
      *attribute,
      expression[MagickPathExtent];

    ChannelType
      channel,
      channel_mask;

    ExceptionInfo
      *exception;

    HV
      *hv;

    Image
      *image;

    ssize_t
      i;

    struct PackageInfo
      *info;

    SV
      *av_reference,
      *perl_exception,
      *reference,
      *rv,
      *sv;

    PERL_UNUSED_VAR(ref);
    PERL_UNUSED_VAR(ix);
    exception=AcquireExceptionInfo();
    perl_exception=newSVpv("",0);
    sv=NULL;
    attribute=NULL;
    av=NULL;
    if (sv_isobject(ST(0)) == 0)
      {
        ThrowPerlException(exception,OptionError,"ReferenceIsNotMyType",
          PackageName);
        goto PerlException;
      }
    reference=SvRV(ST(0));
    hv=SvSTASH(reference);
    av=newAV();
    av_reference=sv_2mortal(sv_bless(newRV((SV *) av),hv));
    SvREFCNT_dec(av);
    image=SetupList(aTHX_ reference,&info,(SV ***) NULL,exception);
    if (image == (Image *) NULL)
      {
        ThrowPerlException(exception,OptionError,"NoImagesDefined",
          PackageName);
        goto PerlException;
      }
    info=GetPackageInfo(aTHX_ (void *) av,info,exception);
    /*
      Get options.
    */
    channel=DefaultChannels;
    (void) CopyMagickString(expression,"u",MagickPathExtent);
    if (items == 2)
      (void) CopyMagickString(expression,(char *) SvPV(ST(1),na),MagickPathExtent);
    else
      for (i=2; i < items; i+=2)
      {
        attribute=(char *) SvPV(ST(i-1),na);
        switch (*attribute)
        {
          case 'C':
          case 'c':
          {
            if (LocaleCompare(attribute,"channel") == 0)
              {
                ssize_t
                  option;

                option=ParseChannelOption(SvPV(ST(i),na));
                if (option < 0)
                  {
                    ThrowPerlException(exception,OptionError,
                      "UnrecognizedType",SvPV(ST(i),na));
                    return;
                  }
                channel=(ChannelType) option;
                break;
              }
            ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
              attribute);
            break;
          }
          case 'E':
          case 'e':
          {
            if (LocaleCompare(attribute,"expression") == 0)
              {
                (void) CopyMagickString(expression,SvPV(ST(i),na),
                  MagickPathExtent);
                break;
              }
            ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
              attribute);
            break;
          }
          default:
          {
            ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
              attribute);
            break;
          }
        }
      }
    channel_mask=SetImageChannelMask(image,channel);
    image=ChannelFxImage(image,expression,exception);
    if (image != (Image *) NULL)
      (void) SetImageChannelMask(image,channel_mask);
    if (image == (Image *) NULL)
      goto PerlException;
    for ( ; image; image=image->next)
    {
      AddImageToRegistry(sv,image);
      rv=newRV(sv);
      av_push(av,sv_bless(rv,hv));
      SvREFCNT_dec(sv);
    }
    exception=DestroyExceptionInfo(exception);
    ST(0)=av_reference;
    SvREFCNT_dec(perl_exception);  /* can't return warning messages */
    XSRETURN(1);

  PerlException:
    InheritPerlException(exception,perl_exception);
    exception=DestroyExceptionInfo(exception);
    sv_setiv(perl_exception,(IV) SvCUR(perl_exception) != 0);
    SvPOK_on(perl_exception);
    ST(0)=sv_2mortal(perl_exception);
    XSRETURN(1);
  }

#
###############################################################################
#                                                                             #
#                                                                             #
#                                                                             #
#   C l o n e                                                                 #
#                                                                             #
#                                                                             #
#                                                                             #
###############################################################################
#
#
void
Clone(ref)
  Image::Magick ref=NO_INIT
  ALIAS:
    CopyImage   = 1
    copy        = 2
    copyimage   = 3
    CloneImage  = 4
    clone       = 5
    cloneimage  = 6
    Clone       = 7
  PPCODE:
  {
    AV
      *av;

    ExceptionInfo
      *exception;

    HV
      *hv;

    Image
      *clone,
      *image;

    struct PackageInfo
      *info;

    SV
      *perl_exception,
      *reference,
      *rv,
      *sv;

    PERL_UNUSED_VAR(ref);
    PERL_UNUSED_VAR(ix);
    exception=AcquireExceptionInfo();
    perl_exception=newSVpv("",0);
    sv=NULL;
    if (sv_isobject(ST(0)) == 0)
      {
        ThrowPerlException(exception,OptionError,"ReferenceIsNotMyType",
          PackageName);
        goto PerlException;
      }
    reference=SvRV(ST(0));
    hv=SvSTASH(reference);
    image=SetupList(aTHX_ reference,&info,(SV ***) NULL,exception);
    if (image == (Image *) NULL)
      {
        ThrowPerlException(exception,OptionError,"NoImagesDefined",
          PackageName);
        goto PerlException;
      }
    /*
      Create blessed Perl array for the returned image.
    */
    av=newAV();
    ST(0)=sv_2mortal(sv_bless(newRV((SV *) av),hv));
    SvREFCNT_dec(av);
    for ( ; image; image=image->next)
    {
      clone=CloneImage(image,0,0,MagickTrue,exception);
      if (clone == (Image *) NULL)
        break;
      AddImageToRegistry(sv,clone);
      rv=newRV(sv);
      av_push(av,sv_bless(rv,hv));
      SvREFCNT_dec(sv);
    }
    exception=DestroyExceptionInfo(exception);
    SvREFCNT_dec(perl_exception);
    XSRETURN(1);

  PerlException:
    InheritPerlException(exception,perl_exception);
    exception=DestroyExceptionInfo(exception);
    sv_setiv(perl_exception,(IV) SvCUR(perl_exception) != 0);
    SvPOK_on(perl_exception);
    ST(0)=sv_2mortal(perl_exception);
    XSRETURN(1);
  }

#
###############################################################################
#                                                                             #
#                                                                             #
#                                                                             #
#   C L O N E                                                                 #
#                                                                             #
#                                                                             #
#                                                                             #
###############################################################################
#
#
void
CLONE(ref,...)
  SV *ref;
  CODE:
  {
    PERL_UNUSED_VAR(ref);
    if (magick_registry != (SplayTreeInfo *) NULL)
      {
        Image
          *p;

        ResetSplayTreeIterator(magick_registry);
        p=(Image *) GetNextKeyInSplayTree(magick_registry);
        while (p != (Image *) NULL)
        {
          ReferenceImage(p);
          p=(Image *) GetNextKeyInSplayTree(magick_registry);
        }
      }
  }

#
###############################################################################
#                                                                             #
#                                                                             #
#                                                                             #
#   C o a l e s c e                                                           #
#                                                                             #
#                                                                             #
#                                                                             #
###############################################################################
#
#
void
Coalesce(ref)
  Image::Magick ref=NO_INIT
  ALIAS:
    CoalesceImage   = 1
    coalesce        = 2
    coalesceimage   = 3
  PPCODE:
  {
    AV
      *av;

    ExceptionInfo
      *exception;

    HV
      *hv;

    Image
      *image;

    struct PackageInfo
      *info;

    SV
      *av_reference,
      *perl_exception,
      *reference,
      *rv,
      *sv;

    PERL_UNUSED_VAR(ref);
    PERL_UNUSED_VAR(ix);
    exception=AcquireExceptionInfo();
    perl_exception=newSVpv("",0);
    sv=NULL;
    if (sv_isobject(ST(0)) == 0)
      {
        ThrowPerlException(exception,OptionError,"ReferenceIsNotMyType",
          PackageName);
        goto PerlException;
      }
    reference=SvRV(ST(0));
    hv=SvSTASH(reference);
    av=newAV();
    av_reference=sv_2mortal(sv_bless(newRV((SV *) av),hv));
    SvREFCNT_dec(av);
    image=SetupList(aTHX_ reference,&info,(SV ***) NULL,exception);
    if (image == (Image *) NULL)
      {
        ThrowPerlException(exception,OptionError,"NoImagesDefined",
          PackageName);
        goto PerlException;
      }
    image=CoalesceImages(image,exception);
    if (image == (Image *) NULL)
      goto PerlException;
    for ( ; image; image=image->next)
    {
      AddImageToRegistry(sv,image);
      rv=newRV(sv);
      av_push(av,sv_bless(rv,hv));
      SvREFCNT_dec(sv);
    }
    exception=DestroyExceptionInfo(exception);
    ST(0)=av_reference;
    SvREFCNT_dec(perl_exception);
    XSRETURN(1);

  PerlException:
    InheritPerlException(exception,perl_exception);
    exception=DestroyExceptionInfo(exception);
    sv_setiv(perl_exception,(IV) SvCUR(perl_exception) != 0);
    SvPOK_on(perl_exception);
    ST(0)=sv_2mortal(perl_exception);
    XSRETURN(1);
  }

#
###############################################################################
#                                                                             #
#                                                                             #
#                                                                             #
#   C o m p a r e                                                             #
#                                                                             #
#                                                                             #
#                                                                             #
###############################################################################
#
#
void
Compare(ref,...)
  Image::Magick ref=NO_INIT
  ALIAS:
    CompareImages = 1
    compare      = 2
    compareimage = 3
  PPCODE:
  {
    AV
      *av;

    char
      *attribute;

    double
      distortion;

    ExceptionInfo
      *exception;

    HV
      *hv;

    Image
      *difference_image,
      *image,
      *reconstruct_image;

    MetricType
      metric;

    ssize_t
      i,
      option;

    struct PackageInfo
      *info;

    SV
      *av_reference,
      *perl_exception,
      *reference,
      *rv,
      *sv;

    PERL_UNUSED_VAR(ref);
    PERL_UNUSED_VAR(ix);
    exception=AcquireExceptionInfo();
    perl_exception=newSVpv("",0);
    sv=NULL;
    av=NULL;
    attribute=NULL;
    if (sv_isobject(ST(0)) == 0)
      {
        ThrowPerlException(exception,OptionError,"ReferenceIsNotMyType",
          PackageName);
        goto PerlException;
      }
    reference=SvRV(ST(0));
    hv=SvSTASH(reference);
    av=newAV();
    av_reference=sv_2mortal(sv_bless(newRV((SV *) av),hv));
    SvREFCNT_dec(av);
    image=SetupList(aTHX_ reference,&info,(SV ***) NULL,exception);
    if (image == (Image *) NULL)
      {
        ThrowPerlException(exception,OptionError,"NoImagesDefined",
          PackageName);
        goto PerlException;
      }
    info=GetPackageInfo(aTHX_ (void *) av,info,exception);
    /*
      Get attribute.
    */
    reconstruct_image=image;
    metric=RootMeanSquaredErrorMetric;
    for (i=2; i < items; i+=2)
    {
      attribute=(char *) SvPV(ST(i-1),na);
      switch (*attribute)
      {
        case 'C':
        case 'c':
        {
          if (LocaleCompare(attribute,"channel") == 0)
            {
              ssize_t
                option;

              option=ParseChannelOption(SvPV(ST(i),na));
              if (option < 0)
                {
                  ThrowPerlException(exception,OptionError,
                    "UnrecognizedType",SvPV(ST(i),na));
                  return;
                }
              (void) SetPixelChannelMask(image,(ChannelType) option);
              break;
            }
          ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
            attribute);
          break;
        }
        case 'F':
        case 'f':
        {
          if (LocaleCompare(attribute,"fuzz") == 0)
            {
              image->fuzz=StringToDoubleInterval(SvPV(ST(i),na),100.0);
              break;
            }
          ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
            attribute);
          break;
        }
        case 'I':
        case 'i':
        {
          if (LocaleCompare(attribute,"image") == 0)
            {
              reconstruct_image=SetupList(aTHX_ SvRV(ST(i)),
                (struct PackageInfo **) NULL,(SV ***) NULL,exception);
              break;
            }
          ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
            attribute);
          break;
        }
        case 'M':
        case 'm':
        {
          if (LocaleCompare(attribute,"metric") == 0)
            {
              option=ParseCommandOption(MagickMetricOptions,MagickFalse,
                SvPV(ST(i),na));
              if (option < 0)
                {
                  ThrowPerlException(exception,OptionError,"UnrecognizedType",
                    SvPV(ST(i),na));
                  break;
                }
              metric=(MetricType) option;
              break;
            }
          ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
            attribute);
          break;
        }
        default:
        {
          ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
            attribute);
          break;
        }
      }
    }
    difference_image=CompareImages(image,reconstruct_image,metric,&distortion,
      exception);
    if (difference_image != (Image *) NULL)
      {
        difference_image->error.mean_error_per_pixel=distortion;
        AddImageToRegistry(sv,difference_image);
        rv=newRV(sv);
        av_push(av,sv_bless(rv,hv));
        SvREFCNT_dec(sv);
      }
    exception=DestroyExceptionInfo(exception);
    ST(0)=av_reference;
    SvREFCNT_dec(perl_exception);  /* can't return warning messages */
    XSRETURN(1);

  PerlException:
    InheritPerlException(exception,perl_exception);
    exception=DestroyExceptionInfo(exception);
    sv_setiv(perl_exception,(IV) SvCUR(perl_exception) != 0);
    SvPOK_on(perl_exception);
    ST(0)=sv_2mortal(perl_exception);
    XSRETURN(1);
  }

#
###############################################################################
#                                                                             #
#                                                                             #
#                                                                             #
#   C o m p l e x I m a g e s                                                 #
#                                                                             #
#                                                                             #
#                                                                             #
###############################################################################
#
#
void
ComplexImages(ref)
  Image::Magick ref=NO_INIT
  ALIAS:
    ComplexImages   = 1
    compleximages   = 2
  PPCODE:
  {
    AV
      *av;

    char
      *attribute,
      *p;

    ComplexOperator
      op;

    ExceptionInfo
      *exception;

    HV
      *hv;

    Image
      *image;

    ssize_t
      i;

    struct PackageInfo
      *info;

    SV
      *perl_exception,
      *reference,
      *rv,
      *sv;

    PERL_UNUSED_VAR(ref);
    PERL_UNUSED_VAR(ix);
    exception=AcquireExceptionInfo();
    perl_exception=newSVpv("",0);
    sv=NULL;
    if (sv_isobject(ST(0)) == 0)
      {
        ThrowPerlException(exception,OptionError,"ReferenceIsNotMyType",
          PackageName);
        goto PerlException;
      }
    reference=SvRV(ST(0));
    hv=SvSTASH(reference);
    image=SetupList(aTHX_ reference,&info,(SV ***) NULL,exception);
    if (image == (Image *) NULL)
      {
        ThrowPerlException(exception,OptionError,"NoImagesDefined",
          PackageName);
        goto PerlException;
      }
    op=UndefinedComplexOperator;
    if (items == 2)
      {
        ssize_t
          in;

        in=ParseCommandOption(MagickComplexOptions,MagickFalse,(char *)
          SvPV(ST(1),na));
        if (in < 0)
          {
            ThrowPerlException(exception,OptionError,"UnrecognizedType",
              SvPV(ST(1),na));
            return;
          }
        op=(ComplexOperator) in;
      }
    else
      for (i=2; i < items; i+=2)
      {
        attribute=(char *) SvPV(ST(i-1),na);
        switch (*attribute)
        {
          case 'O':
          case 'o':
          {
            if (LocaleCompare(attribute,"operator") == 0)
              {
                ssize_t
                  in;

                in=!SvPOK(ST(i)) ? SvIV(ST(i)) : ParseCommandOption(
                  MagickComplexOptions,MagickFalse,SvPV(ST(i),na));
                if (in < 0)
                  {
                    ThrowPerlException(exception,OptionError,"UnrecognizedType",
                      SvPV(ST(i),na));
                    return;
                  }
                op=(ComplexOperator) in;
                break;
              }
            ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
              attribute);
            break;
          }
          default:
          {
            ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
              attribute);
            break;
          }
        }
      }
    image=ComplexImages(image,op,exception);
    if (image == (Image *) NULL)
      goto PerlException;
    /*
      Create blessed Perl array for the returned image.
    */
    av=newAV();
    ST(0)=sv_2mortal(sv_bless(newRV((SV *) av),hv));
    SvREFCNT_dec(av);
    AddImageToRegistry(sv,image);
    rv=newRV(sv);
    av_push(av,sv_bless(rv,hv));
    SvREFCNT_dec(sv);
    info=GetPackageInfo(aTHX_ (void *) av,info,exception);
    (void) FormatLocaleString(info->image_info->filename,MagickPathExtent,
      "complex-%.*s",(int) (MagickPathExtent-9),
      ((p=strrchr(image->filename,'/')) ? p+1 : image->filename));
    (void) CopyMagickString(image->filename,info->image_info->filename,
      MagickPathExtent);
    SetImageInfo(info->image_info,0,exception);
    exception=DestroyExceptionInfo(exception);
    SvREFCNT_dec(perl_exception);
    XSRETURN(1);

  PerlException:
    InheritPerlException(exception,perl_exception);
    exception=DestroyExceptionInfo(exception);
    sv_setiv(perl_exception,(IV) SvCUR(perl_exception) != 0);
    SvPOK_on(perl_exception);
    ST(0)=sv_2mortal(perl_exception);
    XSRETURN(1);
  }

#
###############################################################################
#                                                                             #
#                                                                             #
#                                                                             #
#   C o m p a r e L a y e r s                                                 #
#                                                                             #
#                                                                             #
#                                                                             #
###############################################################################
#
#
void
CompareLayers(ref)
  Image::Magick ref=NO_INIT
  ALIAS:
    CompareImagesLayers   = 1
    comparelayers        = 2
    compareimagelayers   = 3
  PPCODE:
  {
    AV
      *av;

    char
      *attribute;

    ExceptionInfo
      *exception;

    HV
      *hv;

    Image
      *image;

    LayerMethod
      method;

    ssize_t
      i,
      option;

    struct PackageInfo
      *info;

    SV
      *av_reference,
      *perl_exception,
      *reference,
      *rv,
      *sv;

    PERL_UNUSED_VAR(ref);
    PERL_UNUSED_VAR(ix);
    exception=AcquireExceptionInfo();
    perl_exception=newSVpv("",0);
    sv=NULL;
    if (sv_isobject(ST(0)) == 0)
      {
        ThrowPerlException(exception,OptionError,"ReferenceIsNotMyType",
          PackageName);
        goto PerlException;
      }
    reference=SvRV(ST(0));
    hv=SvSTASH(reference);
    av=newAV();
    av_reference=sv_2mortal(sv_bless(newRV((SV *) av),hv));
    SvREFCNT_dec(av);
    image=SetupList(aTHX_ reference,&info,(SV ***) NULL,exception);
    if (image == (Image *) NULL)
      {
        ThrowPerlException(exception,OptionError,"NoImagesDefined",
          PackageName);
        goto PerlException;
      }
    method=CompareAnyLayer;
    for (i=2; i < items; i+=2)
    {
      attribute=(char *) SvPV(ST(i-1),na);
      switch (*attribute)
      {
        case 'M':
        case 'm':
        {
          if (LocaleCompare(attribute,"method") == 0)
            {
              option=ParseCommandOption(MagickLayerOptions,MagickFalse,
                SvPV(ST(i),na));
              if (option < 0)
                {
                  ThrowPerlException(exception,OptionError,"UnrecognizedType",
                    SvPV(ST(i),na));
                  break;
                }
               method=(LayerMethod) option;
              break;
            }
          ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
            attribute);
          break;
        }
        default:
        {
          ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
            attribute);
          break;
        }
      }
    }
    image=CompareImagesLayers(image,method,exception);
    if (image == (Image *) NULL)
      goto PerlException;
    for ( ; image; image=image->next)
    {
      AddImageToRegistry(sv,image);
      rv=newRV(sv);
      av_push(av,sv_bless(rv,hv));
      SvREFCNT_dec(sv);
    }
    exception=DestroyExceptionInfo(exception);
    ST(0)=av_reference;
    SvREFCNT_dec(perl_exception);
    XSRETURN(1);

  PerlException:
    InheritPerlException(exception,perl_exception);
    exception=DestroyExceptionInfo(exception);
    sv_setiv(perl_exception,(IV) SvCUR(perl_exception) != 0);
    SvPOK_on(perl_exception);
    ST(0)=sv_2mortal(perl_exception);
    XSRETURN(1);
  }

#
###############################################################################
#                                                                             #
#                                                                             #
#                                                                             #
#   D e s t r o y                                                             #
#                                                                             #
#                                                                             #
#                                                                             #
###############################################################################
#
#
void
DESTROY(ref)
  Image::Magick ref=NO_INIT
  PPCODE:
  {
    SV
      *reference;

    PERL_UNUSED_VAR(ref);
    if (sv_isobject(ST(0)) == 0)
      croak("ReferenceIsNotMyType");
    reference=SvRV(ST(0));
    switch (SvTYPE(reference))
    {
      case SVt_PVAV:
      {
        char
          message[MagickPathExtent];

        const SV
          *key;

        HV
          *hv;

        GV
          **gvp;

        struct PackageInfo
          *info;

        SV
          *sv;

        /*
          Array (AV *) reference
        */
        (void) FormatLocaleString(message,MagickPathExtent,"package%s%p",
          XS_VERSION,(void *) reference);
        hv=gv_stashpv(PackageName, FALSE);
        if (!hv)
          break;
        gvp=(GV **) hv_fetch(hv,message,(long) strlen(message),FALSE);
        if (!gvp)
          break;
        sv=GvSV(*gvp);
        if (sv && (SvREFCNT(sv) == 1) && SvIOK(sv))
          {
            info=INT2PTR(struct PackageInfo *,SvIV(sv));
            DestroyPackageInfo(info);
          }
        key=hv_delete(hv,message,(long) strlen(message),G_DISCARD);
        (void) key;
        break;
      }
      case SVt_PVMG:
      {
        Image
          *image;

        /*
          Blessed scalar = (Image *) SvIV(reference)
        */
        image=INT2PTR(Image *,SvIV(reference));
        if (image != (Image *) NULL)
          DeleteImageFromRegistry(reference,image);
        break;
      }
      default:
        break;
    }
  }

#
###############################################################################
#                                                                             #
#                                                                             #
#                                                                             #
#   D i s p l a y                                                             #
#                                                                             #
#                                                                             #
#                                                                             #
###############################################################################
#
#
void
Display(ref,...)
  Image::Magick ref=NO_INIT
  ALIAS:
    DisplayImage  = 1
    display       = 2
    displayimage  = 3
  PPCODE:
  {
    ExceptionInfo
      *exception;

    Image
      *image;

    ssize_t
      i;

    struct PackageInfo
      *info,
      *package_info;

    SV
      *perl_exception,
      *reference;

    PERL_UNUSED_VAR(ref);
    PERL_UNUSED_VAR(ix);
    exception=AcquireExceptionInfo();
    perl_exception=newSVpv("",0);
    package_info=(struct PackageInfo *) NULL;
    if (sv_isobject(ST(0)) == 0)
      {
        ThrowPerlException(exception,OptionError,"ReferenceIsNotMyType",
          PackageName);
        goto PerlException;
      }
    reference=SvRV(ST(0));
    image=SetupList(aTHX_ reference,&info,(SV ***) NULL,exception);
    if (image == (Image *) NULL)
      {
        ThrowPerlException(exception,OptionError,"NoImagesDefined",
          PackageName);
        goto PerlException;
      }
    package_info=ClonePackageInfo(info,exception);
    if (items == 2)
      SetAttribute(aTHX_ package_info,NULL,"server",ST(1),exception);
    else
      if (items > 2)
        for (i=2; i < items; i+=2)
          SetAttribute(aTHX_ package_info,image,SvPV(ST(i-1),na),ST(i),
            exception);
    (void) DisplayImages(package_info->image_info,image,exception);
    (void) CatchImageException(image);

  PerlException:
    if (package_info != (struct PackageInfo *) NULL)
      DestroyPackageInfo(package_info);
    InheritPerlException(exception,perl_exception);
    exception=DestroyExceptionInfo(exception);
    sv_setiv(perl_exception,(IV) SvCUR(perl_exception) != 0);
    SvPOK_on(perl_exception);
    ST(0)=sv_2mortal(perl_exception);
    XSRETURN(1);
  }

#
###############################################################################
#                                                                             #
#                                                                             #
#                                                                             #
#   E v a l u a t e I m a g e s                                               #
#                                                                             #
#                                                                             #
#                                                                             #
###############################################################################
#
#
void
EvaluateImages(ref)
  Image::Magick ref=NO_INIT
  ALIAS:
    EvaluateImages   = 1
    evaluateimages   = 2
  PPCODE:
  {
    AV
      *av;

    char
      *attribute,
      *p;

    ExceptionInfo
      *exception;

    HV
      *hv;

    Image
      *image;

    MagickEvaluateOperator
      op;

    ssize_t
      i;

    struct PackageInfo
      *info;

    SV
      *perl_exception,
      *reference,
      *rv,
      *sv;

    PERL_UNUSED_VAR(ref);
    PERL_UNUSED_VAR(ix);
    exception=AcquireExceptionInfo();
    perl_exception=newSVpv("",0);
    sv=NULL;
    if (sv_isobject(ST(0)) == 0)
      {
        ThrowPerlException(exception,OptionError,"ReferenceIsNotMyType",
          PackageName);
        goto PerlException;
      }
    reference=SvRV(ST(0));
    hv=SvSTASH(reference);
    image=SetupList(aTHX_ reference,&info,(SV ***) NULL,exception);
    if (image == (Image *) NULL)
      {
        ThrowPerlException(exception,OptionError,"NoImagesDefined",
          PackageName);
        goto PerlException;
      }
    op=MeanEvaluateOperator;
    if (items == 2)
      {
        ssize_t
          in;

        in=ParseCommandOption(MagickEvaluateOptions,MagickFalse,(char *)
          SvPV(ST(1),na));
        if (in < 0)
          {
            ThrowPerlException(exception,OptionError,"UnrecognizedType",
              SvPV(ST(1),na));
            return;
          }
        op=(MagickEvaluateOperator) in;
      }
    else
      for (i=2; i < items; i+=2)
      {
        attribute=(char *) SvPV(ST(i-1),na);
        switch (*attribute)
        {
          case 'O':
          case 'o':
          {
            if (LocaleCompare(attribute,"operator") == 0)
              {
                ssize_t
                  in;

                in=!SvPOK(ST(i)) ? SvIV(ST(i)) : ParseCommandOption(
                  MagickEvaluateOptions,MagickFalse,SvPV(ST(i),na));
                if (in < 0)
                  {
                    ThrowPerlException(exception,OptionError,"UnrecognizedType",
                      SvPV(ST(i),na));
                    return;
                  }
                op=(MagickEvaluateOperator) in;
                break;
              }
            ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
              attribute);
            break;
          }
          default:
          {
            ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
              attribute);
            break;
          }
        }
      }
    image=EvaluateImages(image,op,exception);
    if (image == (Image *) NULL)
      goto PerlException;
    /*
      Create blessed Perl array for the returned image.
    */
    av=newAV();
    ST(0)=sv_2mortal(sv_bless(newRV((SV *) av),hv));
    SvREFCNT_dec(av);
    AddImageToRegistry(sv,image);
    rv=newRV(sv);
    av_push(av,sv_bless(rv,hv));
    SvREFCNT_dec(sv);
    info=GetPackageInfo(aTHX_ (void *) av,info,exception);
    (void) FormatLocaleString(info->image_info->filename,MagickPathExtent,
      "evaluate-%.*s",(int) (MagickPathExtent-9),
      ((p=strrchr(image->filename,'/')) ? p+1 : image->filename));
    (void) CopyMagickString(image->filename,info->image_info->filename,
      MagickPathExtent);
    SetImageInfo(info->image_info,0,exception);
    exception=DestroyExceptionInfo(exception);
    SvREFCNT_dec(perl_exception);
    XSRETURN(1);

  PerlException:
    InheritPerlException(exception,perl_exception);
    exception=DestroyExceptionInfo(exception);
    sv_setiv(perl_exception,(IV) SvCUR(perl_exception) != 0);
    SvPOK_on(perl_exception);
    ST(0)=sv_2mortal(perl_exception);
    XSRETURN(1);
  }

#
###############################################################################
#                                                                             #
#                                                                             #
#                                                                             #
#   F e a t u r e s                                                           #
#                                                                             #
#                                                                             #
#                                                                             #
###############################################################################
#
#
void
Features(ref,...)
  Image::Magick ref=NO_INIT
  ALIAS:
    FeaturesImage = 1
    features      = 2
    featuresimage = 3
  PPCODE:
  {
#define ChannelFeatures(channel,direction) \
{ \
  (void) FormatLocaleString(message,MagickPathExtent,"%.20g", \
    channel_features[channel].angular_second_moment[direction]); \
  PUSHs(sv_2mortal(newSVpv(message,0))); \
  (void) FormatLocaleString(message,MagickPathExtent,"%.20g", \
    channel_features[channel].contrast[direction]); \
  PUSHs(sv_2mortal(newSVpv(message,0))); \
  (void) FormatLocaleString(message,MagickPathExtent,"%.20g", \
    channel_features[channel].contrast[direction]); \
  PUSHs(sv_2mortal(newSVpv(message,0))); \
  (void) FormatLocaleString(message,MagickPathExtent,"%.20g", \
    channel_features[channel].variance_sum_of_squares[direction]); \
  PUSHs(sv_2mortal(newSVpv(message,0))); \
  (void) FormatLocaleString(message,MagickPathExtent,"%.20g", \
    channel_features[channel].inverse_difference_moment[direction]); \
  PUSHs(sv_2mortal(newSVpv(message,0))); \
  (void) FormatLocaleString(message,MagickPathExtent,"%.20g", \
    channel_features[channel].sum_average[direction]); \
  PUSHs(sv_2mortal(newSVpv(message,0))); \
  (void) FormatLocaleString(message,MagickPathExtent,"%.20g", \
    channel_features[channel].sum_variance[direction]); \
  PUSHs(sv_2mortal(newSVpv(message,0))); \
  (void) FormatLocaleString(message,MagickPathExtent,"%.20g", \
    channel_features[channel].sum_entropy[direction]); \
  PUSHs(sv_2mortal(newSVpv(message,0))); \
  (void) FormatLocaleString(message,MagickPathExtent,"%.20g", \
    channel_features[channel].entropy[direction]); \
  PUSHs(sv_2mortal(newSVpv(message,0))); \
  (void) FormatLocaleString(message,MagickPathExtent,"%.20g", \
    channel_features[channel].difference_variance[direction]); \
  PUSHs(sv_2mortal(newSVpv(message,0))); \
  (void) FormatLocaleString(message,MagickPathExtent,"%.20g", \
    channel_features[channel].difference_entropy[direction]); \
  PUSHs(sv_2mortal(newSVpv(message,0))); \
  (void) FormatLocaleString(message,MagickPathExtent,"%.20g", \
    channel_features[channel].measure_of_correlation_1[direction]); \
  PUSHs(sv_2mortal(newSVpv(message,0))); \
  (void) FormatLocaleString(message,MagickPathExtent,"%.20g", \
    channel_features[channel].measure_of_correlation_2[direction]); \
  PUSHs(sv_2mortal(newSVpv(message,0))); \
  (void) FormatLocaleString(message,MagickPathExtent,"%.20g", \
    channel_features[channel].maximum_correlation_coefficient[direction]); \
  PUSHs(sv_2mortal(newSVpv(message,0))); \
}

    AV
      *av;

    char
      *attribute,
      message[MagickPathExtent];

    ChannelFeatures
      *channel_features;

    double
      distance;

    ExceptionInfo
      *exception;

    Image
      *image;

    ssize_t
      i,
      count;

    struct PackageInfo
      *info;

    SV
      *perl_exception,
      *reference;

    PERL_UNUSED_VAR(ref);
    PERL_UNUSED_VAR(ix);
    exception=AcquireExceptionInfo();
    perl_exception=newSVpv("",0);
    av=NULL;
    if (sv_isobject(ST(0)) == 0)
      {
        ThrowPerlException(exception,OptionError,"ReferenceIsNotMyType",
          PackageName);
        goto PerlException;
      }
    reference=SvRV(ST(0));
    av=newAV();
    SvREFCNT_dec(av);
    image=SetupList(aTHX_ reference,&info,(SV ***) NULL,exception);
    if (image == (Image *) NULL)
      {
        ThrowPerlException(exception,OptionError,"NoImagesDefined",
          PackageName);
        goto PerlException;
      }
    distance=1.0;
    for (i=2; i < items; i+=2)
    {
      attribute=(char *) SvPV(ST(i-1),na);
      switch (*attribute)
      {
        case 'D':
        case 'd':
        {
          if (LocaleCompare(attribute,"distance") == 0)
            {
              distance=StringToLong((char *) SvPV(ST(1),na));
              break;
            }
          ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
            attribute);
          break;
        }
        default:
        {
          ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
            attribute);
          break;
        }
      }
    }
    count=0;
    for ( ; image; image=image->next)
    {
      ssize_t
        j;

      channel_features=GetImageFeatures(image,distance,exception);
      if (channel_features == (ChannelFeatures *) NULL)
        continue;
      count++;
      for (j=0; j < 4; j++)
      {
        for (i=0; i < (ssize_t) GetPixelChannels(image); i++)
        {
          PixelChannel channel=GetPixelChannelChannel(image,i);
          PixelTrait traits=GetPixelChannelTraits(image,channel);
          if (traits == UndefinedPixelTrait)
            continue;
          EXTEND(sp,14*(i+1)*count);
          ChannelFeatures(channel,j);
        }
      }
      channel_features=(ChannelFeatures *)
        RelinquishMagickMemory(channel_features);
    }

  PerlException:
    InheritPerlException(exception,perl_exception);
    exception=DestroyExceptionInfo(exception);
    SvREFCNT_dec(perl_exception);
  }

#
###############################################################################
#                                                                             #
#                                                                             #
#                                                                             #
#   F l a t t e n                                                             #
#                                                                             #
#                                                                             #
#                                                                             #
###############################################################################
#
#
void
Flatten(ref)
  Image::Magick ref=NO_INIT
  ALIAS:
    FlattenImage   = 1
    flatten        = 2
    flattenimage   = 3
  PPCODE:
  {
    AV
      *av;

    char
      *attribute,
      *p;

    ExceptionInfo
      *exception;

    HV
      *hv;

    Image
      *image;

    PixelInfo
      background_color;

    ssize_t
      i;

    struct PackageInfo
      *info;

    SV
      *perl_exception,
      *reference,
      *rv,
      *sv;

    PERL_UNUSED_VAR(ref);
    PERL_UNUSED_VAR(ix);
    exception=AcquireExceptionInfo();
    perl_exception=newSVpv("",0);
    sv=NULL;
    if (sv_isobject(ST(0)) == 0)
      {
        ThrowPerlException(exception,OptionError,"ReferenceIsNotMyType",
          PackageName);
        goto PerlException;
      }
    reference=SvRV(ST(0));
    hv=SvSTASH(reference);
    image=SetupList(aTHX_ reference,&info,(SV ***) NULL,exception);
    if (image == (Image *) NULL)
      {
        ThrowPerlException(exception,OptionError,"NoImagesDefined",
          PackageName);
        goto PerlException;
      }
    background_color=image->background_color;
    if (items == 2)
      (void) QueryColorCompliance((char *) SvPV(ST(1),na),AllCompliance,
        &background_color,exception);
    else
      for (i=2; i < items; i+=2)
      {
        attribute=(char *) SvPV(ST(i-1),na);
        switch (*attribute)
        {
          case 'B':
          case 'b':
          {
            if (LocaleCompare(attribute,"background") == 0)
              {
                (void) QueryColorCompliance((char *) SvPV(ST(1),na),
                  AllCompliance,&background_color,exception);
                break;
              }
            ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
              attribute);
            break;
          }
          default:
          {
            ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
              attribute);
            break;
          }
        }
      }
    image->background_color=background_color;
    image=MergeImageLayers(image,FlattenLayer,exception);
    if (image == (Image *) NULL)
      goto PerlException;
    /*
      Create blessed Perl array for the returned image.
    */
    av=newAV();
    ST(0)=sv_2mortal(sv_bless(newRV((SV *) av),hv));
    SvREFCNT_dec(av);
    AddImageToRegistry(sv,image);
    rv=newRV(sv);
    av_push(av,sv_bless(rv,hv));
    SvREFCNT_dec(sv);
    info=GetPackageInfo(aTHX_ (void *) av,info,exception);
    (void) FormatLocaleString(info->image_info->filename,MagickPathExtent,
      "flatten-%.*s",(int) (MagickPathExtent-9),
      ((p=strrchr(image->filename,'/')) ? p+1 : image->filename));
    (void) CopyMagickString(image->filename,info->image_info->filename,
      MagickPathExtent);
    SetImageInfo(info->image_info,0,exception);
    exception=DestroyExceptionInfo(exception);
    SvREFCNT_dec(perl_exception);
    XSRETURN(1);

  PerlException:
    InheritPerlException(exception,perl_exception);
    exception=DestroyExceptionInfo(exception);
    sv_setiv(perl_exception,(IV) SvCUR(perl_exception) != 0);
    SvPOK_on(perl_exception);  /* return messages in string context */
    ST(0)=sv_2mortal(perl_exception);
    XSRETURN(1);
  }

#
###############################################################################
#                                                                             #
#                                                                             #
#                                                                             #
#   F x                                                                       #
#                                                                             #
#                                                                             #
#                                                                             #
###############################################################################
#
#
void
Fx(ref,...)
  Image::Magick ref=NO_INIT
  ALIAS:
    FxImage  = 1
    fx       = 2
    fximage  = 3
  PPCODE:
  {
    AV
      *av;

    char
      *attribute,
      expression[MagickPathExtent];

    ChannelType
      channel,
      channel_mask;

    ExceptionInfo
      *exception;

    HV
      *hv;

    Image
      *image;

    ssize_t
      i;

    struct PackageInfo
      *info;

    SV
      *av_reference,
      *perl_exception,
      *reference,
      *rv,
      *sv;

    PERL_UNUSED_VAR(ref);
    PERL_UNUSED_VAR(ix);
    exception=AcquireExceptionInfo();
    perl_exception=newSVpv("",0);
    sv=NULL;
    attribute=NULL;
    av=NULL;
    if (sv_isobject(ST(0)) == 0)
      {
        ThrowPerlException(exception,OptionError,"ReferenceIsNotMyType",
          PackageName);
        goto PerlException;
      }
    reference=SvRV(ST(0));
    hv=SvSTASH(reference);
    av=newAV();
    av_reference=sv_2mortal(sv_bless(newRV((SV *) av),hv));
    SvREFCNT_dec(av);
    image=SetupList(aTHX_ reference,&info,(SV ***) NULL,exception);
    if (image == (Image *) NULL)
      {
        ThrowPerlException(exception,OptionError,"NoImagesDefined",
          PackageName);
        goto PerlException;
      }
    info=GetPackageInfo(aTHX_ (void *) av,info,exception);
    /*
      Get options.
    */
    channel=DefaultChannels;
    (void) CopyMagickString(expression,"u",MagickPathExtent);
    if (items == 2)
      (void) CopyMagickString(expression,(char *) SvPV(ST(1),na),MagickPathExtent);
    else
      for (i=2; i < items; i+=2)
      {
        attribute=(char *) SvPV(ST(i-1),na);
        switch (*attribute)
        {
          case 'C':
          case 'c':
          {
            if (LocaleCompare(attribute,"channel") == 0)
              {
                ssize_t
                  option;

                option=ParseChannelOption(SvPV(ST(i),na));
                if (option < 0)
                  {
                    ThrowPerlException(exception,OptionError,
                      "UnrecognizedType",SvPV(ST(i),na));
                    return;
                  }
                channel=(ChannelType) option;
                break;
              }
            ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
              attribute);
            break;
          }
          case 'E':
          case 'e':
          {
            if (LocaleCompare(attribute,"expression") == 0)
              {
                (void) CopyMagickString(expression,SvPV(ST(i),na),
                  MagickPathExtent);
                break;
              }
            ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
              attribute);
            break;
          }
          default:
          {
            ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
              attribute);
            break;
          }
        }
      }
    channel_mask=SetImageChannelMask(image,channel);
    image=FxImage(image,expression,exception);
    if (image != (Image *) NULL)
      (void) SetImageChannelMask(image,channel_mask);
    if (image == (Image *) NULL)
      goto PerlException;
    for ( ; image; image=image->next)
    {
      AddImageToRegistry(sv,image);
      rv=newRV(sv);
      av_push(av,sv_bless(rv,hv));
      SvREFCNT_dec(sv);
    }
    exception=DestroyExceptionInfo(exception);
    ST(0)=av_reference;
    SvREFCNT_dec(perl_exception);  /* can't return warning messages */
    XSRETURN(1);

  PerlException:
    InheritPerlException(exception,perl_exception);
    exception=DestroyExceptionInfo(exception);
    sv_setiv(perl_exception,(IV) SvCUR(perl_exception) != 0);
    SvPOK_on(perl_exception);
    ST(0)=sv_2mortal(perl_exception);
    XSRETURN(1);
  }

#
###############################################################################
#                                                                             #
#                                                                             #
#                                                                             #
#   G e t                                                                     #
#                                                                             #
#                                                                             #
#                                                                             #
###############################################################################
#
#
void
Get(ref,...)
  Image::Magick ref=NO_INIT
  ALIAS:
    GetAttributes = 1
    GetAttribute  = 2
    get           = 3
    getattributes = 4
    getattribute  = 5
  PPCODE:
  {
    char
      *attribute,
      color[MagickPathExtent];

    const char
      *value;

    ExceptionInfo
      *exception;

    Image
      *image;

    long
      j;

    ssize_t
      i;

    struct PackageInfo
      *info;

    SV
      *perl_exception,
      *reference,
      *s;

    PERL_UNUSED_VAR(ref);
    PERL_UNUSED_VAR(ix);
    exception=AcquireExceptionInfo();
    perl_exception=newSVpv("",0);
    if (sv_isobject(ST(0)) == 0)
      {
        ThrowPerlException(exception,OptionError,"ReferenceIsNotMyType",
          PackageName);
        XSRETURN_EMPTY;
      }
    reference=SvRV(ST(0));
    image=SetupList(aTHX_ reference,&info,(SV ***) NULL,exception);
    if (image == (Image *) NULL && !info)
      XSRETURN_EMPTY;
    EXTEND(sp,items);
    for (i=1; i < items; i++)
    {
      attribute=(char *) SvPV(ST(i),na);
      s=NULL;
      switch (*attribute)
      {
        case 'A':
        case 'a':
        {
          if (LocaleCompare(attribute,"adjoin") == 0)
            {
              if (info)
                s=newSViv((ssize_t) info->image_info->adjoin);
              PUSHs(s ? sv_2mortal(s) : &sv_undef);
              continue;
            }
          if (LocaleCompare(attribute,"antialias") == 0)
            {
              if (info)
                s=newSViv((ssize_t) info->image_info->antialias);
              PUSHs(s ? sv_2mortal(s) : &sv_undef);
              continue;
            }
          if (LocaleCompare(attribute,"area") == 0)
            {
              s=newSViv((MagickOffsetType) GetMagickResource(AreaResource));
              PUSHs(s ? sv_2mortal(s) : &sv_undef);
              continue;
            }
          if (LocaleCompare(attribute,"attenuate") == 0)
            {
              const char
                *value;

              value=GetImageProperty(image,attribute,exception);
              if (value != (const char *) NULL)
                s=newSVpv(value,0);
              PUSHs(s ? sv_2mortal(s) : &sv_undef);
              continue;
            }
          if (LocaleCompare(attribute,"authenticate") == 0)
            {
              if (info)
                {
                  const char
                    *option;

                  option=GetImageOption(info->image_info,attribute);
                  if (option != (const char *) NULL)
                    s=newSVpv(option,0);
                }
              PUSHs(s ? sv_2mortal(s) : &sv_undef);
              continue;
            }
          ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
            attribute);
          break;
        }
        case 'B':
        case 'b':
        {
          if (LocaleCompare(attribute,"background") == 0)
            {
              if (image == (Image *) NULL)
                break;
              (void) FormatLocaleString(color,MagickPathExtent,
                "%.20g,%.20g,%.20g,%.20g",(double) image->background_color.red,
                (double) image->background_color.green,
                (double) image->background_color.blue,
                (double) image->background_color.alpha);
              s=newSVpv(color,0);
              PUSHs(s ? sv_2mortal(s) : &sv_undef);
              continue;
            }
          if (LocaleCompare(attribute,"base-columns") == 0)
            {
              if (image != (Image *) NULL)
                s=newSViv((ssize_t) image->magick_columns);
              PUSHs(s ? sv_2mortal(s) : &sv_undef);
              continue;
            }
          if (LocaleCompare(attribute,"base-filename") == 0)
            {
              if (image != (Image *) NULL)
                s=newSVpv(image->magick_filename,0);
              PUSHs(s ? sv_2mortal(s) : &sv_undef);
              continue;
            }
          if (LocaleCompare(attribute,"base-height") == 0)
            {
              if (image != (Image *) NULL)
                s=newSViv((ssize_t) image->magick_rows);
              PUSHs(s ? sv_2mortal(s) : &sv_undef);
              continue;
            }
          if (LocaleCompare(attribute,"base-rows") == 0)
            {
              if (image != (Image *) NULL)
                s=newSViv((ssize_t) image->magick_rows);
              PUSHs(s ? sv_2mortal(s) : &sv_undef);
              continue;
            }
          if (LocaleCompare(attribute,"base-width") == 0)
            {
              if (image != (Image *) NULL)
                s=newSViv((ssize_t) image->magick_columns);
              PUSHs(s ? sv_2mortal(s) : &sv_undef);
              continue;
            }
          if (LocaleCompare(attribute,"blue-primary") == 0)
            {
              if (image == (Image *) NULL)
                break;
              (void) FormatLocaleString(color,MagickPathExtent,"%.20g,%.20g",
                image->chromaticity.blue_primary.x,
                image->chromaticity.blue_primary.y);
              s=newSVpv(color,0);
              PUSHs(s ? sv_2mortal(s) : &sv_undef);
              continue;
            }
          if (LocaleCompare(attribute,"bordercolor") == 0)
            {
              if (image == (Image *) NULL)
                break;
              (void) FormatLocaleString(color,MagickPathExtent,
                "%.20g,%.20g,%.20g,%.20g",(double) image->border_color.red,
                (double) image->border_color.green,
                (double) image->border_color.blue,
                (double) image->border_color.alpha);
              s=newSVpv(color,0);
              PUSHs(s ? sv_2mortal(s) : &sv_undef);
              continue;
            }
          if (LocaleCompare(attribute,"bounding-box") == 0)
            {
              char
                geometry[MagickPathExtent];

              RectangleInfo
                page;

              if (image == (Image *) NULL)
                break;
              page=GetImageBoundingBox(image,exception);
              (void) FormatLocaleString(geometry,MagickPathExtent,
                "%.20gx%.20g%+.20g%+.20g",(double) page.width,(double)
                page.height,(double) page.x,(double) page.y);
              s=newSVpv(geometry,0);
              PUSHs(s ? sv_2mortal(s) : &sv_undef);
              continue;
            }
          ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
            attribute);
          break;
        }
        case 'C':
        case 'c':
        {
          if (LocaleCompare(attribute,"class") == 0)
            {
              if (image == (Image *) NULL)
                break;
              s=newSViv(image->storage_class);
              (void) sv_setpv(s,CommandOptionToMnemonic(MagickClassOptions,
                image->storage_class));
              SvIOK_on(s);
              PUSHs(s ? sv_2mortal(s) : &sv_undef);
              continue;
            }
          if (LocaleCompare(attribute,"clip-mask") == 0)
            {
              if (image != (Image *) NULL)
                {
                  Image
                    *mask_image;

                  SV
                    *sv;

                  sv=NULL;
                  if (image->read_mask == MagickFalse)
                    ClipImage(image,exception);
                  mask_image=GetImageMask(image,ReadPixelMask,exception);
                  if (mask_image != (Image *) NULL)
                    {
                      AddImageToRegistry(sv,mask_image);
                      s=sv_bless(newRV(sv),SvSTASH(reference));
                    }
                }
              PUSHs(s ? sv_2mortal(s) : &sv_undef);
              continue;
            }
          if (LocaleCompare(attribute,"clip-path") == 0)
            {
              if (image != (Image *) NULL)
                {
                  Image
                    *mask_image;

                  SV
                    *sv;

                  sv=NULL;
                  if (image->read_mask != MagickFalse)
                    ClipImage(image,exception);
                  mask_image=GetImageMask(image,ReadPixelMask,exception);
                  if (mask_image != (Image *) NULL)
                    {
                      AddImageToRegistry(sv,mask_image);
                      s=sv_bless(newRV(sv),SvSTASH(reference));
                    }
                }
              PUSHs(s ? sv_2mortal(s) : &sv_undef);
              continue;
            }
          if (LocaleCompare(attribute,"compression") == 0)
            {
              j=info ? info->image_info->compression : image ?
                image->compression : UndefinedCompression;
              if (info)
                if (info->image_info->compression == UndefinedCompression)
                  j=image->compression;
              s=newSViv(j);
              (void) sv_setpv(s,CommandOptionToMnemonic(MagickCompressOptions,
                j));
              SvIOK_on(s);
              PUSHs(s ? sv_2mortal(s) : &sv_undef);
              continue;
            }
          if (LocaleCompare(attribute,"colorspace") == 0)
            {
              j=image ? image->colorspace : RGBColorspace;
              s=newSViv(j);
              (void) sv_setpv(s,CommandOptionToMnemonic(MagickColorspaceOptions,
                j));
              SvIOK_on(s);
              PUSHs(s ? sv_2mortal(s) : &sv_undef);
              continue;
            }
          if (LocaleCompare(attribute,"colors") == 0)
            {
              if (image != (Image *) NULL)
                s=newSViv((ssize_t) GetNumberColors(image,(FILE *) NULL,
                  exception));
              PUSHs(s ? sv_2mortal(s) : &sv_undef);
              continue;
            }
          if (LocaleNCompare(attribute,"colormap",8) == 0)
            {
              int
                items;

              if (image == (Image *) NULL || !image->colormap)
                break;
              j=0;
              items=sscanf(attribute,"%*[^[][%ld",&j);
              (void) items;
              if (j > (ssize_t) image->colors)
                j%=(ssize_t) image->colors;
              (void) FormatLocaleString(color,MagickPathExtent,
                "%.20g,%.20g,%.20g,%.20g",(double) image->colormap[j].red,
                (double) image->colormap[j].green,
                (double) image->colormap[j].blue,
                (double) image->colormap[j].alpha);
              s=newSVpv(color,0);
              PUSHs(s ? sv_2mortal(s) : &sv_undef);
              continue;
            }
          if (LocaleCompare(attribute,"columns") == 0)
            {
              if (image != (Image *) NULL)
                s=newSViv((ssize_t) image->columns);
              PUSHs(s ? sv_2mortal(s) : &sv_undef);
              continue;
            }
          if (LocaleCompare(attribute,"comment") == 0)
            {
              const char
                *value;

              value=GetImageProperty(image,attribute,exception);
              if (value != (const char *) NULL)
                s=newSVpv(value,0);
              PUSHs(s ? sv_2mortal(s) : &sv_undef);
              continue;
            }
          if (LocaleCompare(attribute,"copyright") == 0)
            {
              s=newSVpv(GetMagickCopyright(),0);
              PUSHs(s ? sv_2mortal(s) : &sv_undef);
              continue;
            }
          ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
            attribute);
          break;
        }
        case 'D':
        case 'd':
        {
          if (LocaleCompare(attribute,"density") == 0)
            {
              char
                geometry[MagickPathExtent];

              if (image == (Image *) NULL)
                break;
              (void) FormatLocaleString(geometry,MagickPathExtent,"%.20gx%.20g",
                image->resolution.x,image->resolution.y);
              s=newSVpv(geometry,0);
              PUSHs(s ? sv_2mortal(s) : &sv_undef);
              continue;
            }
          if (LocaleCompare(attribute,"delay") == 0)
            {
              if (image != (Image *) NULL)
                s=newSViv((ssize_t) image->delay);
              PUSHs(s ? sv_2mortal(s) : &sv_undef);
              continue;
            }
          if (LocaleCompare(attribute,"depth") == 0)
            {
              s=newSViv(MAGICKCORE_QUANTUM_DEPTH);
              if (image != (Image *) NULL)
                s=newSViv((ssize_t) GetImageDepth(image,exception));
              PUSHs(s ? sv_2mortal(s) : &sv_undef);
              continue;
            }
          if (LocaleCompare(attribute,"directory") == 0)
            {
              if (image && image->directory)
                s=newSVpv(image->directory,0);
              PUSHs(s ? sv_2mortal(s) : &sv_undef);
              continue;
            }
          if (LocaleCompare(attribute,"dispose") == 0)
            {
              if (image == (Image *) NULL)
                break;

              s=newSViv(image->dispose);
              (void) sv_setpv(s,
                CommandOptionToMnemonic(MagickDisposeOptions,image->dispose));
              SvIOK_on(s);
              PUSHs(s ? sv_2mortal(s) : &sv_undef);
              continue;
            }
          if (LocaleCompare(attribute,"disk") == 0)
            {
              s=newSViv((MagickOffsetType) GetMagickResource(DiskResource));
              PUSHs(s ? sv_2mortal(s) : &sv_undef);
              continue;
            }
          if (LocaleCompare(attribute,"dither") == 0)
            {
              if (info)
                s=newSViv((ssize_t) info->image_info->dither);
              PUSHs(s ? sv_2mortal(s) : &sv_undef);
              continue;
            }
          if (LocaleCompare(attribute,"display") == 0)  /* same as server */
            {
              if (info && info->image_info->server_name)
                s=newSVpv(info->image_info->server_name,0);
              PUSHs(s ? sv_2mortal(s) : &sv_undef);
              continue;
            }
          ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
            attribute);
          break;
        }
        case 'E':
        case 'e':
        {
          if (LocaleCompare(attribute,"elapsed-time") == 0)
            {
              if (image != (Image *) NULL)
                s=newSVnv(GetElapsedTime(&image->timer));
              PUSHs(s ? sv_2mortal(s) : &sv_undef);
              continue;
            }
          if (LocaleCompare(attribute,"endian") == 0)
            {
              j=info ? info->image_info->endian : image ? image->endian :
                UndefinedEndian;
              if (info)
                if (info->image_info->endian == UndefinedEndian)
                  j=image->endian;
              s=newSViv(j);
              (void) sv_setpv(s,CommandOptionToMnemonic(MagickEndianOptions,j));
              SvIOK_on(s);
              PUSHs(s ? sv_2mortal(s) : &sv_undef);
              continue;
            }
          if (LocaleCompare(attribute,"error") == 0)
            {
              if (image != (Image *) NULL)
                s=newSVnv(image->error.mean_error_per_pixel);
              PUSHs(s ? sv_2mortal(s) : &sv_undef);
              continue;
            }
          ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
            attribute);
          break;
        }
        case 'F':
        case 'f':
        {
          if (LocaleCompare(attribute,"filesize") == 0)
            {
              if (image != (Image *) NULL)
                s=newSViv((ssize_t) GetBlobSize(image));
              PUSHs(s ? sv_2mortal(s) : &sv_undef);
              continue;
            }
          if (LocaleCompare(attribute,"filename") == 0)
            {
              if (info && *info->image_info->filename)
                s=newSVpv(info->image_info->filename,0);
              if (image != (Image *) NULL)
                s=newSVpv(image->filename,0);
              PUSHs(s ? sv_2mortal(s) : &sv_undef);
              continue;
            }
          if (LocaleCompare(attribute,"filter") == 0)
            {
              s=image ? newSViv(image->filter) : newSViv(0);
              (void) sv_setpv(s,CommandOptionToMnemonic(MagickFilterOptions,
                image->filter));
              SvIOK_on(s);
              PUSHs(s ? sv_2mortal(s) : &sv_undef);
              continue;
            }
          if (LocaleCompare(attribute,"font") == 0)
            {
              if (info && info->image_info->font)
                s=newSVpv(info->image_info->font,0);
              PUSHs(s ? sv_2mortal(s) : &sv_undef);
              continue;
            }
          if (LocaleCompare(attribute,"foreground") == 0)
            continue;
          if (LocaleCompare(attribute,"format") == 0)
            {
              const MagickInfo
                *magick_info;

              magick_info=(const MagickInfo *) NULL;
              if (info && (*info->image_info->magick != '\0'))
                magick_info=GetMagickInfo(info->image_info->magick,exception);
              if (image != (Image *) NULL)
                magick_info=GetMagickInfo(image->magick,exception);
              if ((magick_info != (const MagickInfo *) NULL) &&
                  (*magick_info->description != '\0'))
                s=newSVpv((char *) magick_info->description,0);
              PUSHs(s ? sv_2mortal(s) : &sv_undef);
              continue;
            }
          if (LocaleCompare(attribute,"fuzz") == 0)
            {
              if (info)
                s=newSVnv(info->image_info->fuzz);
              if (image != (Image *) NULL)
                s=newSVnv(image->fuzz);
              PUSHs(s ? sv_2mortal(s) : &sv_undef);
              continue;
            }
          ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
            attribute);
          break;
        }
        case 'G':
        case 'g':
        {
          if (LocaleCompare(attribute,"gamma") == 0)
            {
              if (image != (Image *) NULL)
                s=newSVnv(image->gamma);
              PUSHs(s ? sv_2mortal(s) : &sv_undef);
              continue;
            }
          if (LocaleCompare(attribute,"geometry") == 0)
            {
              if (image && image->geometry)
                s=newSVpv(image->geometry,0);
              PUSHs(s ? sv_2mortal(s) : &sv_undef);
              continue;
            }
          if (LocaleCompare(attribute,"gravity") == 0)
            {
              s=image ? newSViv(image->gravity) : newSViv(0);
              (void) sv_setpv(s,CommandOptionToMnemonic(MagickGravityOptions,
                image->gravity));
              SvIOK_on(s);
              PUSHs(s ? sv_2mortal(s) : &sv_undef);
              continue;
            }
          if (LocaleCompare(attribute,"green-primary") == 0)
            {
              if (image == (Image *) NULL)
                break;
              (void) FormatLocaleString(color,MagickPathExtent,"%.20g,%.20g",
                image->chromaticity.green_primary.x,
                image->chromaticity.green_primary.y);
              s=newSVpv(color,0);
              PUSHs(s ? sv_2mortal(s) : &sv_undef);
              continue;
            }
          ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
            attribute);
          break;
        }
        case 'H':
        case 'h':
        {
          if (LocaleCompare(attribute,"height") == 0)
            {
              if (image != (Image *) NULL)
                s=newSViv((ssize_t) image->rows);
              PUSHs(s ? sv_2mortal(s) : &sv_undef);
              continue;
            }
          ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
            attribute);
          break;
        }
        case 'I':
        case 'i':
        {
          if (LocaleCompare(attribute,"icc") == 0)
            {
              if (image != (Image *) NULL)
                {
                  const StringInfo
                    *profile;

                  profile=GetImageProfile(image,"icc");
                  if (profile != (StringInfo *) NULL)
                    s=newSVpv((const char *) GetStringInfoDatum(profile),
                      GetStringInfoLength(profile));
                }
              PUSHs(s ? sv_2mortal(s) : &sv_undef);
              continue;
            }
          if (LocaleCompare(attribute,"icm") == 0)
            {
              if (image != (Image *) NULL)
                {
                  const StringInfo
                    *profile;

                  profile=GetImageProfile(image,"icm");
                  if (profile != (const StringInfo *) NULL)
                    s=newSVpv((const char *) GetStringInfoDatum(profile),
                      GetStringInfoLength(profile));
                }
              PUSHs(s ? sv_2mortal(s) : &sv_undef);
              continue;
            }
          if (LocaleCompare(attribute,"id") == 0)
            {
              if (image != (Image *) NULL)
                {
                  char
                    key[MagickPathExtent];

                  MagickBooleanType
                    status;

                  static ssize_t
                    id = 0;

                  (void) FormatLocaleString(key,MagickPathExtent,"%.20g\n",(double)
                    id);
                  status=SetImageRegistry(ImageRegistryType,key,image,
                    exception);
                  (void) status;
                  s=newSViv(id++);
                }
              PUSHs(s ? sv_2mortal(s) : &sv_undef);
              continue;
            }
          if (LocaleNCompare(attribute,"index",5) == 0)
            {
              CacheView
                *image_view;

              char
                name[MagickPathExtent];

              const Quantum
                *p;

              int
                items;

              long
                x,
                y;

              if (image == (Image *) NULL)
                break;
              if (image->storage_class != PseudoClass)
                break;
              x=0;
              y=0;
              items=sscanf(attribute,"%*[^[][%ld%*[,/]%ld",&x,&y);
              (void) items;
              image_view=AcquireVirtualCacheView(image,exception);
              p=GetCacheViewVirtualPixels(image_view,x,y,1,1,exception);
              if (p != (const Quantum *) NULL)
                {
                  (void) FormatLocaleString(name,MagickPathExtent,QuantumFormat,
                    GetPixelIndex(image,p));
                  s=newSVpv(name,0);
                  PUSHs(s ? sv_2mortal(s) : &sv_undef);
                }
              image_view=DestroyCacheView(image_view);
              continue;
            }
          if (LocaleCompare(attribute,"iptc") == 0)
            {
              if (image != (Image *) NULL)
                {
                  const StringInfo
                    *profile;

                  profile=GetImageProfile(image,"iptc");
                  if (profile != (const StringInfo *) NULL)
                    s=newSVpv((const char *) GetStringInfoDatum(profile),
                      GetStringInfoLength(profile));
                }
              PUSHs(s ? sv_2mortal(s) : &sv_undef);
              continue;
            }
          if (LocaleCompare(attribute,"iterations") == 0)  /* same as loop */
            {
              if (image != (Image *) NULL)
                s=newSViv((ssize_t) image->iterations);
              PUSHs(s ? sv_2mortal(s) : &sv_undef);
              continue;
            }
          if (LocaleCompare(attribute,"interlace") == 0)
            {
              j=info ? info->image_info->interlace : image ? image->interlace :
                UndefinedInterlace;
              if (info)
                if (info->image_info->interlace == UndefinedInterlace)
                  j=image->interlace;
              s=newSViv(j);
              (void) sv_setpv(s,CommandOptionToMnemonic(MagickInterlaceOptions,
                j));
              SvIOK_on(s);
              PUSHs(s ? sv_2mortal(s) : &sv_undef);
              continue;
            }
          ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
            attribute);
          break;
        }
        case 'L':
        case 'l':
        {
          if (LocaleCompare(attribute,"label") == 0)
            {
              const char
                *value;

              if (image == (Image *) NULL)
                break;
              value=GetImageProperty(image,"Label",exception);
              if (value != (const char *) NULL)
                s=newSVpv(value,0);
              PUSHs(s ? sv_2mortal(s) : &sv_undef);
              continue;
            }
          if (LocaleCompare(attribute,"loop") == 0)  /* same as iterations */
            {
              if (image != (Image *) NULL)
                s=newSViv((ssize_t) image->iterations);
              PUSHs(s ? sv_2mortal(s) : &sv_undef);
              continue;
            }
          ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
            attribute);
          break;
        }
        case 'M':
        case 'm':
        {
          if (LocaleCompare(attribute,"magick") == 0)
            {
              if (info && *info->image_info->magick)
                s=newSVpv(info->image_info->magick,0);
              if (image != (Image *) NULL)
                s=newSVpv(image->magick,0);
              PUSHs(s ? sv_2mortal(s) : &sv_undef);
              continue;
            }
          if (LocaleCompare(attribute,"map") == 0)
            {
              s=newSViv((MagickOffsetType) GetMagickResource(MapResource));
              PUSHs(s ? sv_2mortal(s) : &sv_undef);
              continue;
            }
          if (LocaleCompare(attribute,"maximum-error") == 0)
            {
              if (image != (Image *) NULL)
                s=newSVnv(image->error.normalized_maximum_error);
              PUSHs(s ? sv_2mortal(s) : &sv_undef);
              continue;
            }
          if (LocaleCompare(attribute,"memory") == 0)
            {
              s=newSViv((MagickOffsetType) GetMagickResource(MemoryResource));
              PUSHs(s ? sv_2mortal(s) : &sv_undef);
              continue;
            }
          if (LocaleCompare(attribute,"mean-error") == 0)
            {
              if (image != (Image *) NULL)
                s=newSVnv(image->error.normalized_mean_error);
              PUSHs(s ? sv_2mortal(s) : &sv_undef);
              continue;
            }
          if (LocaleCompare(attribute,"mime") == 0)
            {
              if (info && *info->image_info->magick)
                s=newSVpv(MagickToMime(info->image_info->magick),0);
              if (image != (Image *) NULL)
                s=newSVpv(MagickToMime(image->magick),0);
              PUSHs(s ? sv_2mortal(s) : &sv_undef);
              continue;
            }
          if (LocaleCompare(attribute,"mattecolor") == 0)
            {
              if (image == (Image *) NULL)
                break;
              (void) FormatLocaleString(color,MagickPathExtent,
                "%.20g,%.20g,%.20g,%.20g",(double) image->alpha_color.red,
                (double) image->alpha_color.green,
                (double) image->alpha_color.blue,
                (double) image->alpha_color.alpha);
              s=newSVpv(color,0);
              PUSHs(s ? sv_2mortal(s) : &sv_undef);
              continue;
            }
          if (LocaleCompare(attribute,"matte") == 0)
            {
              if (image != (Image *) NULL)
                s=newSViv((ssize_t) image->alpha_trait != UndefinedPixelTrait ?
                  1 : 0);
              PUSHs(s ? sv_2mortal(s) : &sv_undef);
              continue;
            }
          if (LocaleCompare(attribute,"mime") == 0)
            {
              const char
                *magick;

              magick=NULL;
              if (info && *info->image_info->magick)
                magick=info->image_info->magick;
              if (image != (Image *) NULL)
                magick=image->magick;
              if (magick)
                {
                  char
                    *mime;

                  mime=MagickToMime(magick);
                  s=newSVpv(mime,0);
                  mime=(char *) RelinquishMagickMemory(mime);
                }
              PUSHs(s ? sv_2mortal(s) : &sv_undef);
              continue;
            }
          if (LocaleCompare(attribute,"monochrome") == 0)
            {
              if (image == (Image *) NULL)
                continue;
              j=info ? info->image_info->monochrome :
                SetImageMonochrome(image,exception);
              s=newSViv(j);
              PUSHs(s ? sv_2mortal(s) : &sv_undef);
              continue;
            }
          if (LocaleCompare(attribute,"montage") == 0)
            {
              if (image && image->montage)
                s=newSVpv(image->montage,0);
              PUSHs(s ? sv_2mortal(s) : &sv_undef);
              continue;
            }
          ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
            attribute);
          break;
        }
        case 'O':
        case 'o':
        {
          if (LocaleCompare(attribute,"orientation") == 0)
            {
              j=info ? info->image_info->orientation : image ?
                image->orientation : UndefinedOrientation;
              if (info)
                if (info->image_info->orientation == UndefinedOrientation)
                  j=image->orientation;
              s=newSViv(j);
              (void) sv_setpv(s,CommandOptionToMnemonic(MagickOrientationOptions,
                j));
              SvIOK_on(s);
              PUSHs(s ? sv_2mortal(s) : &sv_undef);
              continue;
            }
          ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
            attribute);
          break;
        }
        case 'P':
        case 'p':
        {
          if (LocaleCompare(attribute,"page") == 0)
            {
              if (info && info->image_info->page)
                s=newSVpv(info->image_info->page,0);
              if (image != (Image *) NULL)
                {
                  char
                    geometry[MagickPathExtent];

                  (void) FormatLocaleString(geometry,MagickPathExtent,
                    "%.20gx%.20g%+.20g%+.20g",(double) image->page.width,
                    (double) image->page.height,(double) image->page.x,(double)
                    image->page.y);
                  s=newSVpv(geometry,0);
                }
              PUSHs(s ? sv_2mortal(s) : &sv_undef);
              continue;
            }
          if (LocaleCompare(attribute,"page.x") == 0)
            {
              if (image != (Image *) NULL)
                s=newSViv((ssize_t) image->page.x);
              PUSHs(s ? sv_2mortal(s) : &sv_undef);
              continue;
            }
          if (LocaleCompare(attribute,"page.y") == 0)
            {
              if (image != (Image *) NULL)
                s=newSViv((ssize_t) image->page.y);
              PUSHs(s ? sv_2mortal(s) : &sv_undef);
              continue;
            }
          if (LocaleNCompare(attribute,"pixel",5) == 0)
            {
              char
                tuple[MagickPathExtent];

              const Quantum
                *p;

              int
                items;

              long
                x,
                y;

              if (image == (Image *) NULL)
                break;
              x=0;
              y=0;
              items=sscanf(attribute,"%*[^[][%ld%*[,/]%ld",&x,&y);
              (void) items;
              p=GetVirtualPixels(image,x,y,1,1,exception);
              if (image->colorspace != CMYKColorspace)
                (void) FormatLocaleString(tuple,MagickPathExtent,QuantumFormat ","
                  QuantumFormat "," QuantumFormat "," QuantumFormat,
                  GetPixelRed(image,p),GetPixelGreen(image,p),
                  GetPixelBlue(image,p),GetPixelAlpha(image,p));
              else
                (void) FormatLocaleString(tuple,MagickPathExtent,QuantumFormat ","
                  QuantumFormat "," QuantumFormat "," QuantumFormat ","
                  QuantumFormat,GetPixelRed(image,p),GetPixelGreen(image,p),
                  GetPixelBlue(image,p),GetPixelBlack(image,p),
                  GetPixelAlpha(image,p));
              s=newSVpv(tuple,0);
              PUSHs(s ? sv_2mortal(s) : &sv_undef);
              continue;
            }
          if (LocaleCompare(attribute,"pointsize") == 0)
            {
              if (info)
                s=newSViv((ssize_t) info->image_info->pointsize);
              PUSHs(s ? sv_2mortal(s) : &sv_undef);
              continue;
            }
          if (LocaleCompare(attribute,"precision") == 0)
            {
              s=newSViv((ssize_t) GetMagickPrecision());
              PUSHs(s ? sv_2mortal(s) : &sv_undef);
              continue;
            }
          ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
            attribute);
          break;
        }
        case 'Q':
        case 'q':
        {
          if (LocaleCompare(attribute,"quality") == 0)
            {
              if (info)
                s=newSViv((ssize_t) info->image_info->quality);
              if (image != (Image *) NULL)
                s=newSViv((ssize_t) image->quality);
              PUSHs(s ? sv_2mortal(s) : &sv_undef);
              continue;
            }
          if (LocaleCompare(attribute,"quantum") == 0)
            {
              if (info)
                s=newSViv((ssize_t) MAGICKCORE_QUANTUM_DEPTH);
              PUSHs(s ? sv_2mortal(s) : &sv_undef);
              continue;
            }
          ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
            attribute);
          break;
        }
        case 'R':
        case 'r':
        {
          if (LocaleCompare(attribute,"rendering-intent") == 0)
            {
              s=newSViv(image->rendering_intent);
              (void) sv_setpv(s,CommandOptionToMnemonic(MagickIntentOptions,
                image->rendering_intent));
              SvIOK_on(s);
              PUSHs(s ? sv_2mortal(s) : &sv_undef);
              continue;
            }
          if (LocaleCompare(attribute,"red-primary") == 0)
            {
              if (image == (Image *) NULL)
                break;
              (void) FormatLocaleString(color,MagickPathExtent,"%.20g,%.20g",
                image->chromaticity.red_primary.x,
                image->chromaticity.red_primary.y);
              s=newSVpv(color,0);
              PUSHs(s ? sv_2mortal(s) : &sv_undef);
              continue;
            }
          if (LocaleNCompare(attribute,"registry:",9) == 0)
            {
              const char
                *value;

              value=(const char *) GetImageRegistry(StringRegistryType,
                attribute+9,exception);
              if (value != (const char *) NULL)
                s=newSVpv(value,0);
              PUSHs(s ? sv_2mortal(s) : &sv_undef);
              continue;
            }
          if (LocaleCompare(attribute,"rows") == 0)
            {
              if (image != (Image *) NULL)
                s=newSViv((ssize_t) image->rows);
              PUSHs(s ? sv_2mortal(s) : &sv_undef);
              continue;
            }
          ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
            attribute);
          break;
        }
        case 'S':
        case 's':
        {
          if (LocaleCompare(attribute,"sampling-factor") == 0)
            {
              if (info && info->image_info->sampling_factor)
                s=newSVpv(info->image_info->sampling_factor,0);
              PUSHs(s ? sv_2mortal(s) : &sv_undef);
              continue;
            }
          if (LocaleCompare(attribute,"server") == 0)  /* same as display */
            {
              if (info && info->image_info->server_name)
                s=newSVpv(info->image_info->server_name,0);
              PUSHs(s ? sv_2mortal(s) : &sv_undef);
              continue;
            }
          if (LocaleCompare(attribute,"size") == 0)
            {
              if (info && info->image_info->size)
                s=newSVpv(info->image_info->size,0);
              PUSHs(s ? sv_2mortal(s) : &sv_undef);
              continue;
            }
          if (LocaleCompare(attribute,"scene") == 0)
            {
              if (image != (Image *) NULL)
                s=newSViv((ssize_t) image->scene);
              PUSHs(s ? sv_2mortal(s) : &sv_undef);
              continue;
            }
          if (LocaleCompare(attribute,"scenes") == 0)
            {
              if (image != (Image *) NULL)
                s=newSViv((ssize_t) info->image_info->number_scenes);
              PUSHs(s ? sv_2mortal(s) : &sv_undef);
              continue;
            }
          if (LocaleCompare(attribute,"signature") == 0)
            {
              const char
                *value;

              if (image == (Image *) NULL)
                break;
              (void) SignatureImage(image,exception);
              value=GetImageProperty(image,"Signature",exception);
              if (value != (const char *) NULL)
                s=newSVpv(value,0);
              PUSHs(s ? sv_2mortal(s) : &sv_undef);
              continue;
            }
          ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
            attribute);
          break;
        }
        case 'T':
        case 't':
        {
          if (LocaleCompare(attribute,"taint") == 0)
            {
              if (image != (Image *) NULL)
                s=newSViv((ssize_t) IsTaintImage(image));
              PUSHs(s ? sv_2mortal(s) : &sv_undef);
              continue;
            }
          if (LocaleCompare(attribute,"texture") == 0)
            {
              if (info && info->image_info->texture)
                s=newSVpv(info->image_info->texture,0);
              PUSHs(s ? sv_2mortal(s) : &sv_undef);
              continue;
            }
          if (LocaleCompare(attribute,"total-ink-density") == 0)
            {
              s=newSViv(MAGICKCORE_QUANTUM_DEPTH);
              if (image != (Image *) NULL)
                s=newSVnv(GetImageTotalInkDensity(image,exception));
              PUSHs(s ? sv_2mortal(s) : &sv_undef);
              continue;
            }
          if (LocaleCompare(attribute,"transparent-color") == 0)
            {
              if (image == (Image *) NULL)
                break;
              (void) FormatLocaleString(color,MagickPathExtent,
                "%.20g,%.20g,%.20g,%.20g",(double) image->transparent_color.red,
                (double) image->transparent_color.green,
                (double) image->transparent_color.blue,
                (double) image->transparent_color.alpha);
              s=newSVpv(color,0);
              PUSHs(s ? sv_2mortal(s) : &sv_undef);
              continue;
            }
          if (LocaleCompare(attribute,"type") == 0)
            {
              if (image == (Image *) NULL)
                break;
              j=(ssize_t) GetImageType(image);
              s=newSViv(j);
              (void) sv_setpv(s,CommandOptionToMnemonic(MagickTypeOptions,j));
              SvIOK_on(s);
              PUSHs(s ? sv_2mortal(s) : &sv_undef);
              continue;
            }
          ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
            attribute);
          break;
        }
        case 'U':
        case 'u':
        {
          if (LocaleCompare(attribute,"units") == 0)
            {
              j=info ? info->image_info->units : image ? image->units :
                UndefinedResolution;
              if (info)
                if (info->image_info->units == UndefinedResolution)
                  j=image->units;
              if (j == UndefinedResolution)
                s=newSVpv("undefined units",0);
              else
                if (j == PixelsPerInchResolution)
                  s=newSVpv("pixels / inch",0);
                else
                  s=newSVpv("pixels / centimeter",0);
              PUSHs(s ? sv_2mortal(s) : &sv_undef);
              continue;
            }
          if (LocaleCompare(attribute,"user-time") == 0)
            {
              if (image != (Image *) NULL)
                s=newSVnv(GetUserTime(&image->timer));
              PUSHs(s ? sv_2mortal(s) : &sv_undef);
              continue;
            }
          ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
            attribute);
          break;
        }
        case 'V':
        case 'v':
        {
          if (LocaleCompare(attribute,"verbose") == 0)
            {
              if (info)
                s=newSViv((ssize_t) info->image_info->verbose);
              PUSHs(s ? sv_2mortal(s) : &sv_undef);
              continue;
            }
          if (LocaleCompare(attribute,"version") == 0)
            {
              s=newSVpv(GetMagickVersion((size_t *) NULL),0);
              PUSHs(s ? sv_2mortal(s) : &sv_undef);
              continue;
            }
          if (LocaleCompare(attribute,"virtual-pixel") == 0)
            {
              if (image == (Image *) NULL)
                break;
              j=(ssize_t) GetImageVirtualPixelMethod(image);
              s=newSViv(j);
              (void) sv_setpv(s,CommandOptionToMnemonic(
                MagickVirtualPixelOptions,j));
              SvIOK_on(s);
              PUSHs(s ? sv_2mortal(s) : &sv_undef);
              continue;
            }
          ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
            attribute);
          break;
        }
        case 'W':
        case 'w':
        {
          if (LocaleCompare(attribute,"white-point") == 0)
            {
              if (image == (Image *) NULL)
                break;
              (void) FormatLocaleString(color,MagickPathExtent,"%.20g,%.20g",
                image->chromaticity.white_point.x,
                image->chromaticity.white_point.y);
              s=newSVpv(color,0);
              PUSHs(s ? sv_2mortal(s) : &sv_undef);
              continue;
            }
          if (LocaleCompare(attribute,"width") == 0)
            {
              if (image != (Image *) NULL)
                s=newSViv((ssize_t) image->columns);
              PUSHs(s ? sv_2mortal(s) : &sv_undef);
              continue;
            }
          ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
             attribute);
          break;
        }
        case 'X':
        case 'x':
        {
          if (LocaleCompare(attribute,"xmp") == 0)
            {
              if (image != (Image *) NULL)
                {
                  const StringInfo
                    *profile;

                  profile=GetImageProfile(image,"xmp");
                  if (profile != (StringInfo *) NULL)
                    s=newSVpv((const char *) GetStringInfoDatum(profile),
                      GetStringInfoLength(profile));
                }
              PUSHs(s ? sv_2mortal(s) : &sv_undef);
              continue;
            }
          if (LocaleCompare(attribute,"x-resolution") == 0)
            {
              if (image != (Image *) NULL)
                s=newSVnv(image->resolution.x);
              PUSHs(s ? sv_2mortal(s) : &sv_undef);
              continue;
            }
          ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
            attribute);
          break;
        }
        case 'Y':
        case 'y':
        {
          if (LocaleCompare(attribute,"y-resolution") == 0)
            {
              if (image != (Image *) NULL)
                s=newSVnv(image->resolution.y);
              PUSHs(s ? sv_2mortal(s) : &sv_undef);
              continue;
            }
          ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
            attribute);
          break;
        }
        default:
          break;
      }
      if (image == (Image *) NULL)
        ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
          attribute)
      else
        {
          value=GetImageProperty(image,attribute,exception);
          if (value != (const char *) NULL)
            {
              s=newSVpv(value,0);
              PUSHs(s ? sv_2mortal(s) : &sv_undef);
            }
          else
            if (*attribute != '%')
              ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
                attribute)
            else
              {
                 char
                   *meta;

                 meta=InterpretImageProperties(info ? info->image_info :
                   (ImageInfo *) NULL,image,attribute,exception);
                 s=newSVpv(meta,0);
                 PUSHs(s ? sv_2mortal(s) : &sv_undef);
                 meta=(char *) RelinquishMagickMemory(meta);
              }
        }
    }
    exception=DestroyExceptionInfo(exception);
    SvREFCNT_dec(perl_exception);  /* can't return warning messages */
  }

#
###############################################################################
#                                                                             #
#                                                                             #
#                                                                             #
#   G e t A u t h e n t i c P i x e l s                                       #
#                                                                             #
#                                                                             #
#                                                                             #
###############################################################################
#
#
void *
GetAuthenticPixels(ref,...)
  Image::Magick ref = NO_INIT
  ALIAS:
    getauthenticpixels = 1
    GetImagePixels = 2
    getimagepixels = 3
  CODE:
  {
    char
      *attribute;

    ExceptionInfo
      *exception;

    Image
      *image;

    RectangleInfo
      region;

    ssize_t
      i;

    struct PackageInfo
      *info;

    SV
      *perl_exception,
      *reference;

    void
      *blob = NULL;

    PERL_UNUSED_VAR(ref);
    PERL_UNUSED_VAR(ix);
    exception=AcquireExceptionInfo();
    perl_exception=newSVpv("",0);
    if (sv_isobject(ST(0)) == 0)
      {
        ThrowPerlException(exception,OptionError,"ReferenceIsNotMyType",
          PackageName);
        goto PerlException;
      }
    reference=SvRV(ST(0));

    image=SetupList(aTHX_ reference,&info,(SV ***) NULL,exception);
    if (image == (Image *) NULL)
      {
        ThrowPerlException(exception,OptionError,"NoImagesDefined",
          PackageName);
        goto PerlException;
      }

    region.x=0;
    region.y=0;
    region.width=image->columns;
    region.height=1;
    if (items == 1)
      (void) ParseAbsoluteGeometry(SvPV(ST(1),na),&region);
    for (i=2; i < items; i+=2)
    {
      attribute=(char *) SvPV(ST(i-1),na);
      switch (*attribute)
      {
        case 'g':
        case 'G':
        {
          if (LocaleCompare(attribute,"geometry") == 0)
            {
              (void) ParseAbsoluteGeometry(SvPV(ST(i),na),&region);
              break;
            }
          ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
            attribute);
          break;
        }
        case 'H':
        case 'h':
        {
          if (LocaleCompare(attribute,"height") == 0)
            {
              region.height=(size_t) SvIV(ST(i));
              continue;
            }
          ThrowPerlException(exception,OptionError,"UnrecognizedOption",
            attribute);
          break;
        }
        case 'X':
        case 'x':
        {
          if (LocaleCompare(attribute,"x") == 0)
            {
              region.x=SvIV(ST(i));
              continue;
            }
          ThrowPerlException(exception,OptionError,"UnrecognizedOption",
            attribute);
          break;
        }
        case 'Y':
        case 'y':
        {
          if (LocaleCompare(attribute,"y") == 0)
            {
              region.y=SvIV(ST(i));
              continue;
            }
          ThrowPerlException(exception,OptionError,"UnrecognizedOption",
            attribute);
          break;
        }
        case 'W':
        case 'w':
        {
          if (LocaleCompare(attribute,"width") == 0)
            {
              region.width=(size_t) SvIV(ST(i));
              continue;
            }
          ThrowPerlException(exception,OptionError,"UnrecognizedOption",
            attribute);
          break;
        }
      }
    }
    blob=(void *) GetAuthenticPixels(image,region.x,region.y,region.width,
      region.height,exception);
    if (blob != (void *) NULL)
      goto PerlEnd;

  PerlException:
    InheritPerlException(exception,perl_exception);
    exception=DestroyExceptionInfo(exception);
    SvREFCNT_dec(perl_exception);  /* throw away all errors */

  PerlEnd:
    RETVAL = blob;
  }
  OUTPUT:
    RETVAL

#
###############################################################################
#                                                                             #
#                                                                             #
#                                                                             #
#   G e t V i r t u a l P i x e l s                                           #
#                                                                             #
#                                                                             #
#                                                                             #
###############################################################################
#
#
void *
GetVirtualPixels(ref,...)
  Image::Magick ref = NO_INIT
  ALIAS:
    getvirtualpixels = 1
    AcquireImagePixels = 2
    acquireimagepixels = 3
  CODE:
  {
    char
      *attribute;

    const void
      *blob = NULL;

    ExceptionInfo
      *exception;

    Image
      *image;

    RectangleInfo
      region;

    ssize_t
      i;

    struct PackageInfo
      *info;

    SV
      *perl_exception,
      *reference;

    PERL_UNUSED_VAR(ref);
    PERL_UNUSED_VAR(ix);
    exception=AcquireExceptionInfo();
    perl_exception=newSVpv("",0);
    if (sv_isobject(ST(0)) == 0)
      {
        ThrowPerlException(exception,OptionError,"ReferenceIsNotMyType",
          PackageName);
        goto PerlException;
      }
    reference=SvRV(ST(0));

    image=SetupList(aTHX_ reference,&info,(SV ***) NULL,exception);
    if (image == (Image *) NULL)
      {
        ThrowPerlException(exception,OptionError,"NoImagesDefined",
          PackageName);
        goto PerlException;
      }

    region.x=0;
    region.y=0;
    region.width=image->columns;
    region.height=1;
    if (items == 1)
      (void) ParseAbsoluteGeometry(SvPV(ST(1),na),&region);
    for (i=2; i < items; i+=2)
    {
      attribute=(char *) SvPV(ST(i-1),na);
      switch (*attribute)
      {
        case 'g':
        case 'G':
        {
          if (LocaleCompare(attribute,"geometry") == 0)
            {
              (void) ParseAbsoluteGeometry(SvPV(ST(i),na),&region);
              break;
            }
          ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
            attribute);
          break;
        }
        case 'H':
        case 'h':
        {
          if (LocaleCompare(attribute,"height") == 0)
            {
              region.height=(size_t) SvIV(ST(i));
              continue;
            }
          ThrowPerlException(exception,OptionError,"UnrecognizedOption",
            attribute);
          break;
        }
        case 'X':
        case 'x':
        {
          if (LocaleCompare(attribute,"x") == 0)
            {
              region.x=SvIV(ST(i));
              continue;
            }
          ThrowPerlException(exception,OptionError,"UnrecognizedOption",
            attribute);
          break;
        }
        case 'Y':
        case 'y':
        {
          if (LocaleCompare(attribute,"y") == 0)
            {
              region.y=SvIV(ST(i));
              continue;
            }
          ThrowPerlException(exception,OptionError,"UnrecognizedOption",
            attribute);
          break;
        }
        case 'W':
        case 'w':
        {
          if (LocaleCompare(attribute,"width") == 0)
            {
              region.width=(size_t) SvIV(ST(i));
              continue;
            }
          ThrowPerlException(exception,OptionError,"UnrecognizedOption",
            attribute);
          break;
        }
      }
    }
    blob=(const void *) GetVirtualPixels(image,region.x,region.y,region.width,
      region.height,exception);
    if (blob != (void *) NULL)
      goto PerlEnd;

  PerlException:
    InheritPerlException(exception,perl_exception);
    exception=DestroyExceptionInfo(exception);
    SvREFCNT_dec(perl_exception);  /* throw away all errors */

  PerlEnd:
    RETVAL = (void *) blob;
  }
  OUTPUT:
    RETVAL

#
###############################################################################
#                                                                             #
#                                                                             #
#                                                                             #
#   G e t A u t h e n t i c M e t a c o n t e n t                             #
#                                                                             #
#                                                                             #
#                                                                             #
###############################################################################
#
#
void *
GetAuthenticMetacontent(ref,...)
  Image::Magick ref = NO_INIT
  ALIAS:
    getauthenticmetacontent = 1
    GetMetacontent = 2
    getmetacontent = 3
  CODE:
  {
    ExceptionInfo
      *exception;

    Image
      *image;

    struct PackageInfo
      *info;

    SV
      *perl_exception,
      *reference;

    void
      *blob = NULL;

    PERL_UNUSED_VAR(ref);
    PERL_UNUSED_VAR(ix);
    exception=AcquireExceptionInfo();
    perl_exception=newSVpv("",0);
    if (sv_isobject(ST(0)) == 0)
      {
        ThrowPerlException(exception,OptionError,"ReferenceIsNotMyType",
          PackageName);
        goto PerlException;
      }
    reference=SvRV(ST(0));

    image=SetupList(aTHX_ reference,&info,(SV ***) NULL,exception);
    if (image == (Image *) NULL)
      {
        ThrowPerlException(exception,OptionError,"NoImagesDefined",
          PackageName);
        goto PerlException;
      }

    blob=(void *) GetAuthenticMetacontent(image);
    if (blob != (void *) NULL)
      goto PerlEnd;

  PerlException:
    InheritPerlException(exception,perl_exception);
    exception=DestroyExceptionInfo(exception);
    SvREFCNT_dec(perl_exception);  /* throw away all errors */

  PerlEnd:
    RETVAL = blob;
  }
  OUTPUT:
    RETVAL

#
###############################################################################
#                                                                             #
#                                                                             #
#                                                                             #
#   G e t V i r t u a l M e t a c o n t e n t                                 #
#                                                                             #
#                                                                             #
#                                                                             #
###############################################################################
#
#
void *
GetVirtualMetacontent(ref,...)
  Image::Magick ref = NO_INIT
  ALIAS:
    getvirtualmetacontent = 1
  CODE:
  {
    ExceptionInfo
      *exception;

    Image
      *image;

    struct PackageInfo
      *info;

    SV
      *perl_exception,
      *reference;

    void
      *blob = NULL;

    PERL_UNUSED_VAR(ref);
    PERL_UNUSED_VAR(ix);
    exception=AcquireExceptionInfo();
    perl_exception=newSVpv("",0);
    if (sv_isobject(ST(0)) == 0)
      {
        ThrowPerlException(exception,OptionError,"ReferenceIsNotMyType",
          PackageName);
        goto PerlException;
      }
    reference=SvRV(ST(0));

    image=SetupList(aTHX_ reference,&info,(SV ***) NULL,exception);
    if (image == (Image *) NULL)
      {
        ThrowPerlException(exception,OptionError,"NoImagesDefined",
          PackageName);
        goto PerlException;
      }

    blob=(void *) GetVirtualMetacontent(image);
    if (blob != (void *) NULL)
      goto PerlEnd;

  PerlException:
    InheritPerlException(exception,perl_exception);
    exception=DestroyExceptionInfo(exception);
    SvREFCNT_dec(perl_exception);  /* throw away all errors */

  PerlEnd:
    RETVAL = blob;
  }
  OUTPUT:
    RETVAL

#
###############################################################################
#                                                                             #
#                                                                             #
#                                                                             #
#   H i s t o g r a m                                                         #
#                                                                             #
#                                                                             #
#                                                                             #
###############################################################################
#
#
void
Histogram(ref,...)
  Image::Magick ref=NO_INIT
  ALIAS:
    HistogramImage = 1
    histogram      = 2
    histogramimage = 3
  PPCODE:
  {
    AV
      *av;

    char
      message[MagickPathExtent];

    PixelInfo
      *histogram;

    ExceptionInfo
      *exception;

    Image
      *image;

    ssize_t
      i,
      count;

    struct PackageInfo
      *info;

    SV
      *perl_exception,
      *reference;

    size_t
      number_colors;

    PERL_UNUSED_VAR(ref);
    PERL_UNUSED_VAR(ix);
    exception=AcquireExceptionInfo();
    perl_exception=newSVpv("",0);
    av=NULL;
    if (sv_isobject(ST(0)) == 0)
      {
        ThrowPerlException(exception,OptionError,"ReferenceIsNotMyType",
          PackageName);
        goto PerlException;
      }
    reference=SvRV(ST(0));
    av=newAV();
    SvREFCNT_dec(av);
    image=SetupList(aTHX_ reference,&info,(SV ***) NULL,exception);
    if (image == (Image *) NULL)
      {
        ThrowPerlException(exception,OptionError,"NoImagesDefined",
          PackageName);
        goto PerlException;
      }
    count=0;
    for ( ; image; image=image->next)
    {
      histogram=GetImageHistogram(image,&number_colors,exception);
      if (histogram == (PixelInfo *) NULL)
        continue;
      count+=(ssize_t) number_colors;
      EXTEND(sp,6*count);
      for (i=0; i < (ssize_t) number_colors; i++)
      {
        (void) FormatLocaleString(message,MagickPathExtent,"%.20g",
          histogram[i].red);
        PUSHs(sv_2mortal(newSVpv(message,0)));
        (void) FormatLocaleString(message,MagickPathExtent,"%.20g",
          histogram[i].green);
        PUSHs(sv_2mortal(newSVpv(message,0)));
        (void) FormatLocaleString(message,MagickPathExtent,"%.20g",
          histogram[i].blue);
        PUSHs(sv_2mortal(newSVpv(message,0)));
        if (image->colorspace == CMYKColorspace)
          {
            (void) FormatLocaleString(message,MagickPathExtent,"%.20g",
              histogram[i].black);
            PUSHs(sv_2mortal(newSVpv(message,0)));
          }
        (void) FormatLocaleString(message,MagickPathExtent,"%.20g",
          histogram[i].alpha);
        PUSHs(sv_2mortal(newSVpv(message,0)));
        (void) FormatLocaleString(message,MagickPathExtent,"%.20g",(double)
          histogram[i].count);
        PUSHs(sv_2mortal(newSVpv(message,0)));
      }
      histogram=(PixelInfo *) RelinquishMagickMemory(histogram);
    }

  PerlException:
    InheritPerlException(exception,perl_exception);
    exception=DestroyExceptionInfo(exception);
    SvREFCNT_dec(perl_exception);
  }

#
###############################################################################
#                                                                             #
#                                                                             #
#                                                                             #
#   G e t P i x e l                                                           #
#                                                                             #
#                                                                             #
#                                                                             #
###############################################################################
#
#
void
GetPixel(ref,...)
  Image::Magick ref=NO_INIT
  ALIAS:
    getpixel = 1
    getPixel = 2
  PPCODE:
  {
    AV
      *av;

    char
      *attribute;

    const Quantum
      *p;

    ExceptionInfo
      *exception;

    Image
      *image;

    MagickBooleanType
      normalize;

    RectangleInfo
      region;

    ssize_t
      i,
      option;

    struct PackageInfo
      *info;

    SV
      *perl_exception,
      *reference;  /* reference is the SV* of ref=SvIV(reference) */

    PERL_UNUSED_VAR(ref);
    PERL_UNUSED_VAR(ix);
    exception=AcquireExceptionInfo();
    perl_exception=newSVpv("",0);
    reference=SvRV(ST(0));
    av=(AV *) reference;
    info=GetPackageInfo(aTHX_ (void *) av,(struct PackageInfo *) NULL,
      exception);
    image=SetupList(aTHX_ reference,&info,(SV ***) NULL,exception);
    if (image == (Image *) NULL)
      {
        ThrowPerlException(exception,OptionError,"NoImagesDefined",
          PackageName);
        goto PerlException;
      }
    normalize=MagickTrue;
    region.x=0;
    region.y=0;
    region.width=image->columns;
    region.height=1;
    if (items == 1)
      (void) ParseAbsoluteGeometry(SvPV(ST(1),na),&region);
    for (i=2; i < items; i+=2)
    {
      attribute=(char *) SvPV(ST(i-1),na);
      switch (*attribute)
      {
        case 'C':
        case 'c':
        {
          if (LocaleCompare(attribute,"channel") == 0)
            {
              ssize_t
                option;

              option=ParseChannelOption(SvPV(ST(i),na));
              if (option < 0)
                {
                  ThrowPerlException(exception,OptionError,"UnrecognizedType",
                    SvPV(ST(i),na));
                  return;
                }
              (void) SetPixelChannelMask(image,(ChannelType) option);
              break;
            }
          ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
            attribute);
          break;
        }
        case 'g':
        case 'G':
        {
          if (LocaleCompare(attribute,"geometry") == 0)
            {
              (void) ParseAbsoluteGeometry(SvPV(ST(i),na),&region);
              break;
            }
          ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
            attribute);
          break;
        }
        case 'N':
        case 'n':
        {
          if (LocaleCompare(attribute,"normalize") == 0)
            {
              option=ParseCommandOption(MagickBooleanOptions,MagickFalse,
                SvPV(ST(i),na));
              if (option < 0)
                {
                  ThrowPerlException(exception,OptionError,"UnrecognizedType",
                    SvPV(ST(i),na));
                  break;
                }
             normalize=option != 0 ? MagickTrue : MagickFalse;
             break;
            }
          ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
            attribute);
          break;
        }
        case 'x':
        case 'X':
        {
          if (LocaleCompare(attribute,"x") == 0)
            {
              region.x=SvIV(ST(i));
              break;
            }
          ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
            attribute);
          break;
        }
        case 'y':
        case 'Y':
        {
          if (LocaleCompare(attribute,"y") == 0)
            {
              region.y=SvIV(ST(i));
              break;
            }
          ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
            attribute);
          break;
        }
        default:
        {
          ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
            attribute);
          break;
        }
      }
    }
    p=GetVirtualPixels(image,region.x,region.y,1,1,exception);
    if (p == (const Quantum *) NULL)
      PUSHs(&sv_undef);
    else
      {
        double
          scale;

        scale=1.0;
        if (normalize != MagickFalse)
          scale=1.0/QuantumRange;
        if ((GetPixelRedTraits(image) & UpdatePixelTrait) != 0)
          PUSHs(sv_2mortal(newSVnv(scale*GetPixelRed(image,p))));
        if ((GetPixelGreenTraits(image) & UpdatePixelTrait) != 0)
          PUSHs(sv_2mortal(newSVnv(scale*GetPixelGreen(image,p))));
        if ((GetPixelBlueTraits(image) & UpdatePixelTrait) != 0)
          PUSHs(sv_2mortal(newSVnv(scale*GetPixelBlue(image,p))));
        if (((GetPixelBlackTraits(image) & UpdatePixelTrait) != 0) &&
            (image->colorspace == CMYKColorspace))
          PUSHs(sv_2mortal(newSVnv(scale*GetPixelBlack(image,p))));
        if ((GetPixelAlphaTraits(image) & UpdatePixelTrait) != 0)
          PUSHs(sv_2mortal(newSVnv(scale*GetPixelAlpha(image,p))));
      }

  PerlException:
    InheritPerlException(exception,perl_exception);
    exception=DestroyExceptionInfo(exception);
    SvREFCNT_dec(perl_exception);
  }

#
###############################################################################
#                                                                             #
#                                                                             #
#                                                                             #
#   G e t P i x e l s                                                         #
#                                                                             #
#                                                                             #
#                                                                             #
###############################################################################
#
#
void
GetPixels(ref,...)
  Image::Magick ref=NO_INIT
  ALIAS:
    getpixels = 1
    getPixels = 2
  PPCODE:
  {
    AV
      *av;

    char
      *attribute;

    const char
      *map;

    ExceptionInfo
      *exception;

    Image
      *image;

    MagickBooleanType
      normalize,
      status;

    RectangleInfo
      region;

    ssize_t
      i,
      option;

    struct PackageInfo
      *info;

    SV
      *perl_exception,
      *reference;  /* reference is the SV* of ref=SvIV(reference) */

    PERL_UNUSED_VAR(ref);
    PERL_UNUSED_VAR(ix);
    exception=AcquireExceptionInfo();
    perl_exception=newSVpv("",0);
    reference=SvRV(ST(0));
    av=(AV *) reference;
    info=GetPackageInfo(aTHX_ (void *) av,(struct PackageInfo *) NULL,
      exception);
    image=SetupList(aTHX_ reference,&info,(SV ***) NULL,exception);
    if (image == (Image *) NULL)
      {
        ThrowPerlException(exception,OptionError,"NoImagesDefined",
          PackageName);
        goto PerlException;
      }
    map="RGB";
    if (image->alpha_trait != UndefinedPixelTrait)
      map="RGBA";
    if (image->colorspace == CMYKColorspace)
      {
        map="CMYK";
        if (image->alpha_trait != UndefinedPixelTrait)
          map="CMYKA";
      }
    normalize=MagickFalse;
    region.x=0;
    region.y=0;
    region.width=image->columns;
    region.height=1;
    if (items == 1)
      (void) ParseAbsoluteGeometry(SvPV(ST(1),na),&region);
    for (i=2; i < items; i+=2)
    {
      attribute=(char *) SvPV(ST(i-1),na);
      switch (*attribute)
      {
        case 'g':
        case 'G':
        {
          if (LocaleCompare(attribute,"geometry") == 0)
            {
              (void) ParseAbsoluteGeometry(SvPV(ST(i),na),&region);
              break;
            }
          ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
            attribute);
          break;
        }
        case 'H':
        case 'h':
        {
          if (LocaleCompare(attribute,"height") == 0)
            {
              region.height=(size_t) SvIV(ST(i));
              break;
            }
          ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
            attribute);
          break;
        }
        case 'M':
        case 'm':
        {
          if (LocaleCompare(attribute,"map") == 0)
            {
              map=SvPV(ST(i),na);
              break;
            }
          ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
            attribute);
          break;
        }
        case 'N':
        case 'n':
        {
          if (LocaleCompare(attribute,"normalize") == 0)
            {
              option=ParseCommandOption(MagickBooleanOptions,MagickFalse,
                SvPV(ST(i),na));
              if (option < 0)
                {
                  ThrowPerlException(exception,OptionError,"UnrecognizedType",
                    SvPV(ST(i),na));
                  break;
                }
             normalize=option != 0 ? MagickTrue : MagickFalse;
             break;
            }
          ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
            attribute);
          break;
        }
        case 'W':
        case 'w':
        {
          if (LocaleCompare(attribute,"width") == 0)
            {
              region.width=(size_t) SvIV(ST(i));
              break;
            }
          ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
            attribute);
          break;
        }
        case 'x':
        case 'X':
        {
          if (LocaleCompare(attribute,"x") == 0)
            {
              region.x=SvIV(ST(i));
              break;
            }
          ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
            attribute);
          break;
        }
        case 'y':
        case 'Y':
        {
          if (LocaleCompare(attribute,"y") == 0)
            {
              region.y=SvIV(ST(i));
              break;
            }
          ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
            attribute);
          break;
        }
        default:
        {
          ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
            attribute);
          break;
        }
      }
    }
    if (normalize != MagickFalse)
      {
        float
          *pixels;

        MemoryInfo
          *pixels_info;

        pixels_info=AcquireVirtualMemory(strlen(map)*region.width,
          region.height*sizeof(*pixels));
        if (pixels_info == (MemoryInfo *) NULL)
          {
            ThrowPerlException(exception,ResourceLimitError,
              "MemoryAllocationFailed",PackageName);
            goto PerlException;
          }
        pixels=(float *) GetVirtualMemoryBlob(pixels_info);
        status=ExportImagePixels(image,region.x,region.y,region.width,
          region.height,map,FloatPixel,pixels,exception);
        if (status == MagickFalse)
          PUSHs(&sv_undef);
        else
          {
            EXTEND(sp,(ssize_t) (strlen(map)*region.width*region.height));
            for (i=0; i < (ssize_t) (strlen(map)*region.width*region.height); i++)
              PUSHs(sv_2mortal(newSVnv(pixels[i])));
          }
        pixels_info=RelinquishVirtualMemory(pixels_info);
      }
    else
      {
        MemoryInfo
          *pixels_info;

        Quantum
          *pixels;

        pixels_info=AcquireVirtualMemory(strlen(map)*region.width,
          region.height*sizeof(*pixels));
        if (pixels_info == (MemoryInfo *) NULL)
          {
            ThrowPerlException(exception,ResourceLimitError,
              "MemoryAllocationFailed",PackageName);
            goto PerlException;
          }
        pixels=(Quantum *) GetVirtualMemoryBlob(pixels_info);
        status=ExportImagePixels(image,region.x,region.y,region.width,
          region.height,map,QuantumPixel,pixels,exception);
        if (status == MagickFalse)
          PUSHs(&sv_undef);
        else
          {
            EXTEND(sp,(ssize_t) (strlen(map)*region.width*region.height));
            for (i=0; i < (ssize_t) (strlen(map)*region.width*region.height); i++)
              PUSHs(sv_2mortal(newSViv(pixels[i])));
          }
        pixels_info=RelinquishVirtualMemory(pixels_info);
      }

  PerlException:
    InheritPerlException(exception,perl_exception);
    exception=DestroyExceptionInfo(exception);
    SvREFCNT_dec(perl_exception);
  }

#
###############################################################################
#                                                                             #
#                                                                             #
#                                                                             #
#   I m a g e T o B l o b                                                     #
#                                                                             #
#                                                                             #
#                                                                             #
###############################################################################
#
#
void
ImageToBlob(ref,...)
  Image::Magick ref=NO_INIT
  ALIAS:
    ImageToBlob  = 1
    imagetoblob  = 2
    toblob       = 3
    blob         = 4
  PPCODE:
  {
    char
      filename[MagickPathExtent];

    ExceptionInfo
      *exception;

    Image
      *image,
      *next;

    ssize_t
      i;

    struct PackageInfo
      *info,
      *package_info;

    size_t
      length;

    ssize_t
      scene;

    SV
      *perl_exception,
      *reference;

    void
      *blob;

    PERL_UNUSED_VAR(ref);
    PERL_UNUSED_VAR(ix);
    exception=AcquireExceptionInfo();
    perl_exception=newSVpv("",0);
    package_info=(struct PackageInfo *) NULL;
    if (sv_isobject(ST(0)) == 0)
      {
        ThrowPerlException(exception,OptionError,"ReferenceIsNotMyType",
          PackageName);
        goto PerlException;
      }
    reference=SvRV(ST(0));
    image=SetupList(aTHX_ reference,&info,(SV ***) NULL,exception);
    if (image == (Image *) NULL)
      {
        ThrowPerlException(exception,OptionError,"NoImagesDefined",
          PackageName);
        goto PerlException;
      }
    package_info=ClonePackageInfo(info,exception);
    for (i=2; i < items; i+=2)
      SetAttribute(aTHX_ package_info,image,SvPV(ST(i-1),na),ST(i),exception);
    (void) CopyMagickString(filename,package_info->image_info->filename,
      MagickPathExtent);
    scene=0;
    for (next=image; next; next=next->next)
    {
      (void) CopyMagickString(next->filename,filename,MagickPathExtent);
      next->scene=(size_t) scene++;
    }
    SetImageInfo(package_info->image_info,(unsigned int)
      GetImageListLength(image),exception);
    EXTEND(sp,(ssize_t) GetImageListLength(image));
    for ( ; image; image=image->next)
    {
      length=0;
      blob=ImagesToBlob(package_info->image_info,image,&length,exception);
      if (blob != (char *) NULL)
        {
          PUSHs(sv_2mortal(newSVpv((const char *) blob,length)));
          blob=(unsigned char *) RelinquishMagickMemory(blob);
        }
      if (package_info->image_info->adjoin)
        break;
    }

  PerlException:
    if (package_info != (struct PackageInfo *) NULL)
      DestroyPackageInfo(package_info);
    InheritPerlException(exception,perl_exception);
    exception=DestroyExceptionInfo(exception);
    SvREFCNT_dec(perl_exception);  /* throw away all errors */
  }

#
###############################################################################
#                                                                             #
#                                                                             #
#                                                                             #
#   L a y e r s                                                               #
#                                                                             #
#                                                                             #
#                                                                             #
###############################################################################
#
#
void
Layers(ref,...)
  Image::Magick ref=NO_INIT
  ALIAS:
    Layers                = 1
    layers           = 2
    OptimizeImageLayers   = 3
    optimizelayers        = 4
    optimizeimagelayers   = 5
  PPCODE:
  {
    AV
      *av;

    char
      *attribute;

    CompositeOperator
      compose;

    ExceptionInfo
      *exception;

    HV
      *hv;

    Image
      *image,
      *layers;

    LayerMethod
      method;

    ssize_t
      i,
      option,
      sp;

    struct PackageInfo
      *info;

    SV
      *av_reference,
      *perl_exception,
      *reference,
      *rv,
      *sv;

    PERL_UNUSED_VAR(ref);
    PERL_UNUSED_VAR(ix);
    exception=AcquireExceptionInfo();
    perl_exception=newSVpv("",0);
    sv=NULL;
    if (sv_isobject(ST(0)) == 0)
      {
        ThrowPerlException(exception,OptionError,"ReferenceIsNotMyType",
          PackageName);
        goto PerlException;
      }
    reference=SvRV(ST(0));
    hv=SvSTASH(reference);
    av=newAV();
    av_reference=sv_2mortal(sv_bless(newRV((SV *) av),hv));
    SvREFCNT_dec(av);
    image=SetupList(aTHX_ reference,&info,(SV ***) NULL,exception);
    if (image == (Image *) NULL)
      {
        ThrowPerlException(exception,OptionError,"NoImagesDefined",
          PackageName);
        goto PerlException;
      }
    compose=image->compose;
    method=OptimizeLayer;
    for (i=2; i < items; i+=2)
    {
      attribute=(char *) SvPV(ST(i-1),na);
      switch (*attribute)
      {
        case 'C':
        case 'c':
        {
          if (LocaleCompare(attribute,"compose") == 0)
            {
              sp=!SvPOK(ST(i)) ? SvIV(ST(i)) : ParseCommandOption(
                MagickComposeOptions,MagickFalse,SvPV(ST(i),na));
              if (sp < 0)
                {
                  ThrowPerlException(exception,OptionError,"UnrecognizedType",
                    SvPV(ST(i),na));
                  break;
                }
              compose=(CompositeOperator) sp;
              break;
            }
          ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
            attribute);
          break;
        }
        case 'M':
        case 'm':
        {
          if (LocaleCompare(attribute,"method") == 0)
            {
              option=ParseCommandOption(MagickLayerOptions,MagickFalse,
                SvPV(ST(i),na));
              if (option < 0)
                {
                  ThrowPerlException(exception,OptionError,"UnrecognizedType",
                    SvPV(ST(i),na));
                  break;
                }
              method=(LayerMethod) option;
              break;
            }
          ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
            attribute);
          break;
        }
        default:
        {
          ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
            attribute);
          break;
        }
      }
    }
    layers=(Image *) NULL;
    switch (method)
    {
      case CompareAnyLayer:
      case CompareClearLayer:
      case CompareOverlayLayer:
      default:
      {
        layers=CompareImagesLayers(image,method,exception);
        break;
      }
      case MergeLayer:
      case FlattenLayer:
      case MosaicLayer:
      {
        layers=MergeImageLayers(image,method,exception);
        break;
      }
      case DisposeLayer:
      {
        layers=DisposeImages(image,exception);
        break;
      }
      case OptimizeImageLayer:
      {
        layers=OptimizeImageLayers(image,exception);
        break;
      }
      case OptimizePlusLayer:
      {
        layers=OptimizePlusImageLayers(image,exception);
        break;
      }
      case OptimizeTransLayer:
      {
        OptimizeImageTransparency(image,exception);
        break;
      }
      case RemoveDupsLayer:
      {
        RemoveDuplicateLayers(&image,exception);
        break;
      }
      case RemoveZeroLayer:
      {
        RemoveZeroDelayLayers(&image,exception);
        break;
      }
      case OptimizeLayer:
      {
        QuantizeInfo
          *quantize_info;

        /*
          General Purpose, GIF Animation Optimizer.
        */
        layers=CoalesceImages(image,exception);
        if (layers == (Image *) NULL)
          break;
        image=layers;
        layers=OptimizeImageLayers(image,exception);
        if (layers == (Image *) NULL)
          break;
        image=DestroyImageList(image);
        image=layers;
        layers=(Image *) NULL;
        OptimizeImageTransparency(image,exception);
        quantize_info=AcquireQuantizeInfo(info->image_info);
        (void) RemapImages(quantize_info,image,(Image *) NULL,exception);
        quantize_info=DestroyQuantizeInfo(quantize_info);
        break;
      }
      case CompositeLayer:
      {
        Image
          *source;

        RectangleInfo
          geometry;

        /*
          Split image sequence at the first 'NULL:' image.
        */
        source=image;
        while (source != (Image *) NULL)
        {
          source=GetNextImageInList(source);
          if ((source != (Image *) NULL) &&
              (LocaleCompare(source->magick,"NULL") == 0))
            break;
        }
        if (source != (Image *) NULL)
          {
            if ((GetPreviousImageInList(source) == (Image *) NULL) ||
                (GetNextImageInList(source) == (Image *) NULL))
              source=(Image *) NULL;
            else
              {
                /*
                  Separate the two lists, junk the null: image.
                */
                source=SplitImageList(source->previous);
                DeleteImageFromList(&source);
              }
          }
        if (source == (Image *) NULL)
          {
            (void) ThrowMagickException(exception,GetMagickModule(),
              OptionError,"MissingNullSeparator","layers Composite");
            break;
          }
        /*
          Adjust offset with gravity and virtual canvas.
        */
        SetGeometry(image,&geometry);
        (void) ParseAbsoluteGeometry(image->geometry,&geometry);
        geometry.width=source->page.width != 0 ? source->page.width :
          source->columns;
        geometry.height=source->page.height != 0 ? source->page.height :
          source->rows;
        GravityAdjustGeometry(image->page.width != 0 ? image->page.width :
          image->columns,image->page.height != 0 ? image->page.height :
          image->rows,image->gravity,&geometry);
        CompositeLayers(image,compose,source,geometry.x,geometry.y,exception);
        source=DestroyImageList(source);
        break;
      }
    }
    if (layers != (Image *) NULL)
      image=layers;
    else
      image=CloneImage(image,0,0,MagickTrue,exception);
    if (image == (Image *) NULL)
      goto PerlException;
    for ( ; image; image=image->next)
    {
      AddImageToRegistry(sv,image);
      rv=newRV(sv);
      av_push(av,sv_bless(rv,hv));
      SvREFCNT_dec(sv);
    }
    exception=DestroyExceptionInfo(exception);
    ST(0)=av_reference;
    SvREFCNT_dec(perl_exception);
    XSRETURN(1);

  PerlException:
    InheritPerlException(exception,perl_exception);
    exception=DestroyExceptionInfo(exception);
    sv_setiv(perl_exception,(IV) SvCUR(perl_exception) != 0);
    SvPOK_on(perl_exception);
    ST(0)=sv_2mortal(perl_exception);
    XSRETURN(1);
  }

#
###############################################################################
#                                                                             #
#                                                                             #
#                                                                             #
#   M a g i c k T o M i m e                                                   #
#                                                                             #
#                                                                             #
#                                                                             #
###############################################################################
#
#
SV *
MagickToMime(ref,name)
  Image::Magick ref=NO_INIT
  char *name
  ALIAS:
    magicktomime = 1
  CODE:
  {
    char
      *mime;

    PERL_UNUSED_VAR(ref);
    PERL_UNUSED_VAR(ix);
    mime=MagickToMime(name);
    RETVAL=newSVpv(mime,0);
    mime=(char *) RelinquishMagickMemory(mime);
  }
  OUTPUT:
    RETVAL

#
###############################################################################
#                                                                             #
#                                                                             #
#                                                                             #
#   M o g r i f y                                                             #
#                                                                             #
#                                                                             #
#                                                                             #
###############################################################################
#
#
void
Mogrify(ref,...)
  Image::Magick ref=NO_INIT
  ALIAS:
    Comment            =   1
    CommentImage       =   2
    Label              =   3
    LabelImage         =   4
    AddNoise           =   5
    AddNoiseImage      =   6
    Colorize           =   7
    ColorizeImage      =   8
    Border             =   9
    BorderImage        =  10
    Blur               =  11
    BlurImage          =  12
    Chop               =  13
    ChopImage          =  14
    Crop               =  15
    CropImage          =  16
    Despeckle          =  17
    DespeckleImage     =  18
    Edge               =  19
    EdgeImage          =  20
    Emboss             =  21
    EmbossImage        =  22
    Enhance            =  23
    EnhanceImage       =  24
    Flip               =  25
    FlipImage          =  26
    Flop               =  27
    FlopImage          =  28
    Frame              =  29
    FrameImage         =  30
    Implode            =  31
    ImplodeImage       =  32
    Magnify            =  33
    MagnifyImage       =  34
    MedianFilter       =  35
    MedianConvolveImage  =  36
    Minify             =  37
    MinifyImage        =  38
    OilPaint           =  39
    OilPaintImage      =  40
    ReduceNoise        =  41
    ReduceNoiseImage   =  42
    Roll               =  43
    RollImage          =  44
    Rotate             =  45
    RotateImage        =  46
    Sample             =  47
    SampleImage        =  48
    Scale              =  49
    ScaleImage         =  50
    Shade              =  51
    ShadeImage         =  52
    Sharpen            =  53
    SharpenImage       =  54
    Shear              =  55
    ShearImage         =  56
    Spread             =  57
    SpreadImage        =  58
    Swirl              =  59
    SwirlImage         =  60
    Resize             =  61
    ResizeImage        =  62
    Zoom               =  63
    ZoomImage          =  64
    Annotate           =  65
    AnnotateImage      =  66
    ColorFloodfill     =  67
    ColorFloodfillImage=  68
    Composite          =  69
    CompositeImage     =  70
    Contrast           =  71
    ContrastImage      =  72
    CycleColormap      =  73
    CycleColormapImage =  74
    Draw               =  75
    DrawImage          =  76
    Equalize           =  77
    EqualizeImage      =  78
    Gamma              =  79
    GammaImage         =  80
    Map                =  81
    MapImage           =  82
    MatteFloodfill     =  83
    MatteFloodfillImage=  84
    Modulate           =  85
    ModulateImage      =  86
    Negate             =  87
    NegateImage        =  88
    Normalize          =  89
    NormalizeImage     =  90
    NumberColors       =  91
    NumberColorsImage  =  92
    Opaque             =  93
    OpaqueImage        =  94
    Quantize           =  95
    QuantizeImage      =  96
    Raise              =  97
    RaiseImage         =  98
    Segment            =  99
    SegmentImage       = 100
    Signature          = 101
    SignatureImage     = 102
    Solarize           = 103
    SolarizeImage      = 104
    Sync               = 105
    SyncImage          = 106
    Texture            = 107
    TextureImage       = 108
    Evaluate           = 109
    EvaluateImage      = 110
    Transparent        = 111
    TransparentImage   = 112
    Threshold          = 113
    ThresholdImage     = 114
    Charcoal           = 115
    CharcoalImage      = 116
    Trim               = 117
    TrimImage          = 118
    Wave               = 119
    WaveImage          = 120
    Separate           = 121
    SeparateImage      = 122
    Stereo             = 125
    StereoImage        = 126
    Stegano            = 127
    SteganoImage       = 128
    Deconstruct        = 129
    DeconstructImage   = 130
    GaussianBlur       = 131
    GaussianBlurImage  = 132
    Convolve           = 133
    ConvolveImage      = 134
    Profile            = 135
    ProfileImage       = 136
    UnsharpMask        = 137
    UnsharpMaskImage   = 138
    MotionBlur         = 139
    MotionBlurImage    = 140
    OrderedDither      = 141
    OrderedDitherImage = 142
    Shave              = 143
    ShaveImage         = 144
    Level              = 145
    LevelImage         = 146
    Clip               = 147
    ClipImage          = 148
    AffineTransform    = 149
    AffineTransformImage = 150
    Difference         = 151
    DifferenceImage    = 152
    AdaptiveThreshold  = 153
    AdaptiveThresholdImage = 154
    Resample           = 155
    ResampleImage      = 156
    Describe           = 157
    DescribeImage      = 158
    BlackThreshold     = 159
    BlackThresholdImage= 160
    WhiteThreshold     = 161
    WhiteThresholdImage= 162
    RotationalBlur     = 163
    RotationalBlurImage= 164
    Thumbnail          = 165
    ThumbnailImage     = 166
    Strip              = 167
    StripImage         = 168
    Tint               = 169
    TintImage          = 170
    Channel            = 171
    ChannelImage       = 172
    Splice             = 173
    SpliceImage        = 174
    Posterize          = 175
    PosterizeImage     = 176
    Shadow             = 177
    ShadowImage        = 178
    Identify           = 179
    IdentifyImage      = 180
    SepiaTone          = 181
    SepiaToneImage     = 182
    SigmoidalContrast  = 183
    SigmoidalContrastImage = 184
    Extent             = 185
    ExtentImage        = 186
    Vignette           = 187
    VignetteImage      = 188
    ContrastStretch    = 189
    ContrastStretchImage = 190
    Sans0              = 191
    Sans0Image         = 192
    Sans1              = 193
    Sans1Image         = 194
    AdaptiveSharpen    = 195
    AdaptiveSharpenImage = 196
    Transpose          = 197
    TransposeImage     = 198
    Transverse         = 199
    TransverseImage    = 200
    AutoOrient         = 201
    AutoOrientImage    = 202
    AdaptiveBlur       = 203
    AdaptiveBlurImage  = 204
    Sketch             = 205
    SketchImage        = 206
    UniqueColors       = 207
    UniqueColorsImage  = 208
    AdaptiveResize     = 209
    AdaptiveResizeImage= 210
    ClipMask           = 211
    ClipMaskImage      = 212
    LinearStretch      = 213
    LinearStretchImage = 214
    ColorMatrix        = 215
    ColorMatrixImage   = 216
    Mask               = 217
    MaskImage          = 218
    Polaroid           = 219
    PolaroidImage      = 220
    FloodfillPaint     = 221
    FloodfillPaintImage= 222
    Distort            = 223
    DistortImage       = 224
    Clut               = 225
    ClutImage          = 226
    LiquidRescale      = 227
    LiquidRescaleImage = 228
    Encipher           = 229
    EncipherImage      = 230
    Decipher           = 231
    DecipherImage      = 232
    Deskew             = 233
    DeskewImage        = 234
    Remap              = 235
    RemapImage         = 236
    SparseColor        = 237
    SparseColorImage   = 238
    Function           = 239
    FunctionImage      = 240
    SelectiveBlur      = 241
    SelectiveBlurImage = 242
    HaldClut           = 243
    HaldClutImage      = 244
    BlueShift          = 245
    BlueShiftImage     = 246
    ForwardFourierTransform  = 247
    ForwardFourierTransformImage = 248
    InverseFourierTransform = 249
    InverseFourierTransformImage = 250
    ColorDecisionList  = 251
    ColorDecisionListImage = 252
    AutoGamma          = 253
    AutoGammaImage     = 254
    AutoLevel          = 255
    AutoLevelImage     = 256
    LevelColors        = 257
    LevelImageColors   = 258
    Clamp              = 259
    ClampImage         = 260
    BrightnessContrast = 261
    BrightnessContrastImage = 262
    Morphology         = 263
    MorphologyImage    = 264
    Mode               = 265
    ModeImage          = 266
    Statistic          = 267
    StatisticImage     = 268
    Perceptible        = 269
    PerceptibleImage   = 270
    Poly               = 271
    PolyImage          = 272
    Grayscale          = 273
    GrayscaleImage     = 274
    CannyEdge          = 275
    CannyEdgeImage     = 276
    HoughLine          = 277
    HoughLineImage     = 278
    MeanShift          = 279
    MeanShiftImage     = 280
    Kuwahara           = 281
    KuwaharaImage      = 282
    ConnectedComponents = 283
    ConnectedComponentsImage = 284
    CopyPixels         = 285
    CopyImagePixels    = 286
    Color              = 287
    ColorImage         = 288
    WaveletDenoise     = 289
    WaveletDenoiseImage= 290
    Colorspace         = 291
    ColorspaceImage    = 292
    AutoThreshold      = 293
    AutoThresholdImage = 294
    RangeThreshold     = 295
    RangeThresholdImage= 296
    CLAHE              = 297
    CLAHEImage         = 298
    Kmeans             = 299
    KMeansImage        = 300
    ColorThreshold     = 301
    ColorThresholdImage= 302
    WhiteBalance       = 303
    WhiteBalanceImage  = 304
    BilateralBlur      = 305
    BilateralBlurImage = 306
    SortPixels         = 307
    SortPixelsImage    = 308
    Integral           = 309
    IntegralImage      = 310
    MogrifyRegion      = 666
  PPCODE:
  {
    AffineMatrix
      affine,
      current;

    char
      attribute_flag[MaxArguments],
      message[MagickPathExtent];

    ChannelType
      channel,
      channel_mask;

    CompositeOperator
      compose;

    const char
      *attribute,
      *value;

    double
      angle;

    ExceptionInfo
      *exception;

    GeometryInfo
      geometry_info;

    Image
      *image,
      *next;

    MagickStatusType
      flags;

    PixelInfo
      fill_color;

    RectangleInfo
      geometry,
      region_info;

    ssize_t
      base,
      i,
      j,
      number_images;

    struct Methods
      *rp;

    struct PackageInfo
      *info;

    SV
      *perl_exception,
      **pv,
      *reference,
      **reference_vector;

    struct ArgumentList
      argument_list[MaxArguments];

    PERL_UNUSED_VAR(ref);
    PERL_UNUSED_VAR(ix);
    exception=AcquireExceptionInfo();
    perl_exception=newSVpv("",0);
    reference_vector=NULL;
    number_images=0;
    base=2;
    if (sv_isobject(ST(0)) == 0)
      {
        ThrowPerlException(exception,OptionError,"ReferenceIsNotMyType",
          PackageName);
        goto PerlException;
      }
    reference=SvRV(ST(0));
    region_info.width=0;
    region_info.height=0;
    region_info.x=0;
    region_info.y=0;
    image=SetupList(aTHX_ reference,&info,&reference_vector,exception);
    if (ix && (ix != 666))
      {
        /*
          Called as Method(...)
        */
        ix=(ix+1)/2;
        rp=(&Methods[ix-1]);
        attribute=rp->name;
      }
    else
      {
        /*
          Called as Mogrify("Method",...)
        */
        attribute=(char *) SvPV(ST(1),na);
        if (ix)
          {
            flags=ParseGravityGeometry(image,attribute,&region_info,exception);
            attribute=(char *) SvPV(ST(2),na);
            base++;
          }
        for (rp=Methods; ; rp++)
        {
          if (rp >= EndOf(Methods))
            {
              ThrowPerlException(exception,OptionError,
                "UnrecognizedPerlMagickMethod",attribute);
              goto PerlException;
            }
          if (strEQcase(attribute,rp->name))
            break;
        }
        ix=rp-Methods+1;
        base++;
      }
    if (image == (Image *) NULL)
      {
        ThrowPerlException(exception,OptionError,"NoImagesDefined",attribute);
        goto PerlException;
      }
    Zero(&argument_list,NumberOf(argument_list),struct ArgumentList);
    Zero(&attribute_flag,NumberOf(attribute_flag),char);
    for (i=base; (i < items) || ((i == items) && (base == items)); i+=2)
    {
      Arguments
        *pp,
        *qq;

      ssize_t
        ssize_test;

      struct ArgumentList
        *al;

      SV
        *sv;

      sv=NULL;
      ssize_test=0;
      pp=(Arguments *) NULL;
      qq=rp->arguments;
      if (i == items)
        {
          pp=rp->arguments,
          sv=ST(i-1);
        }
      else
        for (sv=ST(i), attribute=(char *) SvPV(ST(i-1),na); ; qq++)
        {
          if ((qq >= EndOf(rp->arguments)) || (qq->method == NULL))
            break;
          if (strEQcase(attribute,qq->method) > ssize_test)
            {
              pp=qq;
              ssize_test=strEQcase(attribute,qq->method);
            }
        }
      if (pp == (Arguments *) NULL)
        {
          ThrowPerlException(exception,OptionError,"UnrecognizedOption",
            attribute);
          goto continue_outer_loop;
        }
      al=(&argument_list[pp-rp->arguments]);
      switch (pp->type)
      {
        case ArrayReference:
        {
          if (SvTYPE(sv) != SVt_RV)
            {
              (void) FormatLocaleString(message,MagickPathExtent,
                "invalid %.60s value",pp->method);
              ThrowPerlException(exception,OptionError,message,SvPV(sv,na));
              goto continue_outer_loop;
            }
          al->array_reference=SvRV(sv);
          break;
        }
        case RealReference:
        {
          al->real_reference=SvNV(sv);
          break;
        }
        case FileReference:
        {
          al->file_reference=(FILE *) PerlIO_findFILE(IoIFP(sv_2io(sv)));
          break;
        }
        case ImageReference:
        {
          if (!sv_isobject(sv) ||
              !(al->image_reference=SetupList(aTHX_ SvRV(sv),
                (struct PackageInfo **) NULL,(SV ***) NULL,exception)))
            {
              ThrowPerlException(exception,OptionError,"ReferenceIsNotMyType",
                PackageName);
              goto PerlException;
            }
          break;
        }
        case IntegerReference:
        {
          al->integer_reference=SvIV(sv);
          break;
        }
        case StringReference:
        {
          al->string_reference=(char *) SvPV(sv,al->length);
          if (sv_isobject(sv))
            al->image_reference=SetupList(aTHX_ SvRV(sv),
              (struct PackageInfo **) NULL,(SV ***) NULL,exception);
          break;
        }
        default:
        {
          /*
            Is a string; look up name.
          */
          if ((al->length > 1) && (*(char *) SvPV(sv,al->length) == '@'))
            {
              al->string_reference=(char *) SvPV(sv,al->length);
              al->integer_reference=(-1);
              break;
            }
          al->integer_reference=ParseCommandOption((CommandOption) pp->type,
            MagickFalse,SvPV(sv,na));
          if (pp->type == MagickChannelOptions)
            al->integer_reference=ParseChannelOption(SvPV(sv,na));
          if ((al->integer_reference < 0) && ((al->integer_reference=SvIV(sv)) <= 0))
            {
              (void) FormatLocaleString(message,MagickPathExtent,
                "invalid %.60s value",pp->method);
              ThrowPerlException(exception,OptionError,message,SvPV(sv,na));
              goto continue_outer_loop;
            }
          break;
        }
      }
      attribute_flag[pp-rp->arguments]++;
      continue_outer_loop: ;
    }
    (void) ResetMagickMemory((char *) &fill_color,0,sizeof(fill_color));
    pv=reference_vector;
    SetGeometryInfo(&geometry_info);
    channel=DefaultChannels;
    for (next=image; next; next=next->next)
    {
      image=next;
      SetGeometry(image,&geometry);
      if ((region_info.width*region_info.height) != 0)
        (void) SetImageRegionMask(image,WritePixelMask,&region_info,exception);
      switch (ix)
      {
        default:
        {
          (void) FormatLocaleString(message,MagickPathExtent,"%.20g",(double) ix);
          ThrowPerlException(exception,OptionError,
            "UnrecognizedPerlMagickMethod",message);
          goto PerlException;
        }
        case 1:  /* Comment */
        {
          if (attribute_flag[0] == 0)
            argument_list[0].string_reference=(char *) NULL;
          (void) SetImageProperty(image,"comment",InterpretImageProperties(
            info ? info->image_info : (ImageInfo *) NULL,image,
            argument_list[0].string_reference,exception),exception);
          break;
        }
        case 2:  /* Label */
        {
          if (attribute_flag[0] == 0)
            argument_list[0].string_reference=(char *) NULL;
          (void) SetImageProperty(image,"label",InterpretImageProperties(
            info ? info->image_info : (ImageInfo *) NULL,image,
            argument_list[0].string_reference,exception),exception);
          break;
        }
        case 3:  /* AddNoise */
        {
          double
            attenuate;

          if (attribute_flag[0] == 0)
            argument_list[0].integer_reference=UniformNoise;
          attenuate=1.0;
          if (attribute_flag[1] != 0)
            attenuate=argument_list[1].real_reference;
          if (attribute_flag[2] != 0)
            channel=(ChannelType) argument_list[2].integer_reference;
          channel_mask=SetImageChannelMask(image,channel);
          image=AddNoiseImage(image,(NoiseType)
            argument_list[0].integer_reference,attenuate,exception);
          if (image != (Image *) NULL)
            (void) SetImageChannelMask(image,channel_mask);
          break;
        }
        case 4:  /* Colorize */
        {
          PixelInfo
            target;

          (void) GetOneVirtualPixelInfo(image,UndefinedVirtualPixelMethod,
            0,0,&target,exception);
          if (attribute_flag[0] != 0)
            (void) QueryColorCompliance(argument_list[0].string_reference,
              AllCompliance,&target,exception);
          if (attribute_flag[1] == 0)
            argument_list[1].string_reference="100%";
          image=ColorizeImage(image,argument_list[1].string_reference,&target,
            exception);
          break;
        }
        case 5:  /* Border */
        {
          CompositeOperator
            compose;

          geometry.width=0;
          geometry.height=0;
          if (attribute_flag[0] != 0)
            flags=ParsePageGeometry(image,argument_list[0].string_reference,
              &geometry,exception);
          if (attribute_flag[1] != 0)
            geometry.width=(size_t) argument_list[1].integer_reference;
          if (attribute_flag[2] != 0)
            geometry.height=(size_t) argument_list[2].integer_reference;
          if (attribute_flag[3] != 0)
            QueryColorCompliance(argument_list[3].string_reference,
              AllCompliance,&image->border_color,exception);
          if (attribute_flag[4] != 0)
            QueryColorCompliance(argument_list[4].string_reference,
              AllCompliance,&image->border_color,exception);
          if (attribute_flag[5] != 0)
            QueryColorCompliance(argument_list[5].string_reference,
              AllCompliance,&image->border_color,exception);
          compose=image->compose;
          if (attribute_flag[6] != 0)
            compose=(CompositeOperator) argument_list[6].integer_reference;
          image=BorderImage(image,&geometry,compose,exception);
          break;
        }
        case 6:  /* Blur */
        {
          if (attribute_flag[0] != 0)
            {
              flags=ParseGeometry(argument_list[0].string_reference,
                &geometry_info);
              if ((flags & SigmaValue) == 0)
                geometry_info.sigma=1.0;
            }
          if (attribute_flag[1] != 0)
            geometry_info.rho=argument_list[1].real_reference;
          if (attribute_flag[2] != 0)
            geometry_info.sigma=argument_list[2].real_reference;
          if (attribute_flag[3] != 0)
            channel=(ChannelType) argument_list[3].integer_reference;
          channel_mask=SetImageChannelMask(image,channel);
          image=BlurImage(image,geometry_info.rho,geometry_info.sigma,
            exception);
          if (image != (Image *) NULL)
            (void) SetImageChannelMask(image,channel_mask);
          break;
        }
        case 7:  /* Chop */
        {
          if (attribute_flag[5] != 0)
            image->gravity=(GravityType) argument_list[5].integer_reference;
          if (attribute_flag[0] != 0)
            flags=ParseGravityGeometry(image,argument_list[0].string_reference,
              &geometry,exception);
          if (attribute_flag[1] != 0)
            geometry.width=(size_t) argument_list[1].integer_reference;
          if (attribute_flag[2] != 0)
            geometry.height=(size_t) argument_list[2].integer_reference;
          if (attribute_flag[3] != 0)
            geometry.x=argument_list[3].integer_reference;
          if (attribute_flag[4] != 0)
            geometry.y=argument_list[4].integer_reference;
          image=ChopImage(image,&geometry,exception);
          break;
        }
        case 8:  /* Crop */
        {
          if (attribute_flag[6] != 0)
            image->gravity=(GravityType) argument_list[6].integer_reference;
          if (attribute_flag[0] != 0)
            flags=ParseGravityGeometry(image,argument_list[0].string_reference,
              &geometry,exception);
          if (attribute_flag[1] != 0)
            geometry.width=(size_t) argument_list[1].integer_reference;
          if (attribute_flag[2] != 0)
            geometry.height=(size_t) argument_list[2].integer_reference;
          if (attribute_flag[3] != 0)
            geometry.x=argument_list[3].integer_reference;
          if (attribute_flag[4] != 0)
            geometry.y=argument_list[4].integer_reference;
          if (attribute_flag[5] != 0)
            image->fuzz=StringToDoubleInterval(
              argument_list[5].string_reference,(double) QuantumRange+1.0);
          image=CropImage(image,&geometry,exception);
          break;
        }
        case 9:  /* Despeckle */
        {
          image=DespeckleImage(image,exception);
          break;
        }
        case 10:  /* Edge */
        {
          if (attribute_flag[0] != 0)
            geometry_info.rho=argument_list[0].real_reference;
          image=EdgeImage(image,geometry_info.rho,exception);
          break;
        }
        case 11:  /* Emboss */
        {
          if (attribute_flag[0] != 0)
            {
              flags=ParseGeometry(argument_list[0].string_reference,
                &geometry_info);
              if ((flags & SigmaValue) == 0)
                geometry_info.sigma=1.0;
            }
          if (attribute_flag[1] != 0)
            geometry_info.rho=argument_list[1].real_reference;
          if (attribute_flag[2] != 0)
            geometry_info.sigma=argument_list[2].real_reference;
          image=EmbossImage(image,geometry_info.rho,geometry_info.sigma,
            exception);
          break;
        }
        case 12:  /* Enhance */
        {
          image=EnhanceImage(image,exception);
          break;
        }
        case 13:  /* Flip */
        {
          image=FlipImage(image,exception);
          break;
        }
        case 14:  /* Flop */
        {
          image=FlopImage(image,exception);
          break;
        }
        case 15:  /* Frame */
        {
          CompositeOperator
            compose;

          FrameInfo
            frame_info;

          if (attribute_flag[0] != 0)
            {
              flags=ParsePageGeometry(image,argument_list[0].string_reference,
                &geometry,exception);
              frame_info.width=geometry.width;
              frame_info.height=geometry.height;
              frame_info.outer_bevel=geometry.x;
              frame_info.inner_bevel=geometry.y;
            }
          if (attribute_flag[1] != 0)
            frame_info.width=(size_t) argument_list[1].integer_reference;
          if (attribute_flag[2] != 0)
            frame_info.height=(size_t) argument_list[2].integer_reference;
          if (attribute_flag[3] != 0)
            frame_info.inner_bevel=argument_list[3].integer_reference;
          if (attribute_flag[4] != 0)
            frame_info.outer_bevel=argument_list[4].integer_reference;
          if (attribute_flag[5] != 0)
            QueryColorCompliance(argument_list[5].string_reference,
              AllCompliance,&fill_color,exception);
          if (attribute_flag[6] != 0)
            QueryColorCompliance(argument_list[6].string_reference,
              AllCompliance,&fill_color,exception);
          frame_info.x=(ssize_t) frame_info.width;
          frame_info.y=(ssize_t) frame_info.height;
          frame_info.width=(size_t) ((ssize_t) image->columns+2*frame_info.x);
          frame_info.height=(size_t) ((ssize_t) image->rows+2*frame_info.y);
          if ((attribute_flag[5] != 0) || (attribute_flag[6] != 0))
            image->alpha_color=fill_color;
          compose=image->compose;
          if (attribute_flag[7] != 0)
            compose=(CompositeOperator) argument_list[7].integer_reference;
          image=FrameImage(image,&frame_info,compose,exception);
          break;
        }
        case 16:  /* Implode */
        {
          PixelInterpolateMethod
            method;

          if (attribute_flag[0] == 0)
            argument_list[0].real_reference=0.5;
          method=UndefinedInterpolatePixel;
          if (attribute_flag[1] != 0)
            method=(PixelInterpolateMethod) argument_list[1].integer_reference;
          image=ImplodeImage(image,argument_list[0].real_reference,
            method,exception);
          break;
        }
        case 17:  /* Magnify */
        {
          image=MagnifyImage(image,exception);
          break;
        }
        case 18:  /* MedianFilter */
        {
          if (attribute_flag[0] != 0)
            {
              flags=ParseGeometry(argument_list[0].string_reference,
                &geometry_info);
              if ((flags & SigmaValue) == 0)
                geometry_info.sigma=geometry_info.rho;
            }
          if (attribute_flag[1] != 0)
            geometry_info.rho=argument_list[1].real_reference;
          if (attribute_flag[2] != 0)
            geometry_info.sigma=argument_list[2].real_reference;
          if (attribute_flag[3] != 0)
            channel=(ChannelType) argument_list[3].integer_reference;
          channel_mask=SetImageChannelMask(image,channel);
          image=StatisticImage(image,MedianStatistic,(size_t) geometry_info.rho,
            (size_t) geometry_info.sigma,exception);
          if (image != (Image *) NULL)
            (void) SetImageChannelMask(image,channel_mask);
          break;
        }
        case 19:  /* Minify */
        {
          image=MinifyImage(image,exception);
          break;
        }
        case 20:  /* OilPaint */
        {
          if (attribute_flag[0] == 0)
            argument_list[0].real_reference=0.0;
          if (attribute_flag[1] == 0)
            argument_list[1].real_reference=1.0;
          image=OilPaintImage(image,argument_list[0].real_reference,
            argument_list[1].real_reference,exception);
          break;
        }
        case 21:  /* ReduceNoise */
        {
          if (attribute_flag[0] != 0)
            {
              flags=ParseGeometry(argument_list[0].string_reference,
                &geometry_info);
              if ((flags & SigmaValue) == 0)
                geometry_info.sigma=1.0;
            }
          if (attribute_flag[1] != 0)
            geometry_info.rho=argument_list[1].real_reference;
          if (attribute_flag[2] != 0)
            geometry_info.sigma=argument_list[2].real_reference;
          if (attribute_flag[3] != 0)
            channel=(ChannelType) argument_list[3].integer_reference;
          channel_mask=SetImageChannelMask(image,channel);
          image=StatisticImage(image,NonpeakStatistic,(size_t)
            geometry_info.rho,(size_t) geometry_info.sigma,exception);
          if (image != (Image *) NULL)
            (void) SetImageChannelMask(image,channel_mask);
          break;
        }
        case 22:  /* Roll */
        {
          if (attribute_flag[0] != 0)
            {
              flags=ParsePageGeometry(image,argument_list[0].string_reference,
                &geometry,exception);
              if ((flags & PercentValue) != 0)
                {
                  geometry.x*=(double) image->columns/100.0;
                  geometry.y*=(double) image->rows/100.0;
                }
            }
          if (attribute_flag[1] != 0)
            geometry.x=argument_list[1].integer_reference;
          if (attribute_flag[2] != 0)
            geometry.y=argument_list[2].integer_reference;
          image=RollImage(image,geometry.x,geometry.y,exception);
          break;
        }
        case 23:  /* Rotate */
        {
          if (attribute_flag[0] == 0)
            argument_list[0].real_reference=90.0;
          if (attribute_flag[1] != 0)
            {
              QueryColorCompliance(argument_list[1].string_reference,
                AllCompliance,&image->background_color,exception);
              if ((image->background_color.alpha_trait != UndefinedPixelTrait) &&
                  (image->alpha_trait == UndefinedPixelTrait))
                (void) SetImageAlpha(image,OpaqueAlpha,exception);
            }
          image=RotateImage(image,argument_list[0].real_reference,exception);
          break;
        }
        case 24:  /* Sample */
        {
          if (attribute_flag[0] != 0)
            flags=ParseRegionGeometry(image,argument_list[0].string_reference,
              &geometry,exception);
          if (attribute_flag[1] != 0)
            geometry.width=(size_t) argument_list[1].integer_reference;
          if (attribute_flag[2] != 0)
            geometry.height=(size_t) argument_list[2].integer_reference;
          image=SampleImage(image,geometry.width,geometry.height,exception);
          break;
        }
        case 25:  /* Scale */
        {
          if (attribute_flag[0] != 0)
            flags=ParseRegionGeometry(image,argument_list[0].string_reference,
              &geometry,exception);
          if (attribute_flag[1] != 0)
            geometry.width=(size_t) argument_list[1].integer_reference;
          if (attribute_flag[2] != 0)
            geometry.height=(size_t) argument_list[2].integer_reference;
          image=ScaleImage(image,geometry.width,geometry.height,exception);
          break;
        }
        case 26:  /* Shade */
        {
          if (attribute_flag[0] != 0)
            {
              flags=ParseGeometry(argument_list[0].string_reference,
                &geometry_info);
              if ((flags & SigmaValue) == 0)
                geometry_info.sigma=0.0;
            }
          if (attribute_flag[1] != 0)
            geometry_info.rho=argument_list[1].real_reference;
          if (attribute_flag[2] != 0)
            geometry_info.sigma=argument_list[2].real_reference;
          image=ShadeImage(image,
            argument_list[3].integer_reference != 0 ? MagickTrue : MagickFalse,
            geometry_info.rho,geometry_info.sigma,exception);
          break;
        }
        case 27:  /* Sharpen */
        {
          if (attribute_flag[0] != 0)
            {
              flags=ParseGeometry(argument_list[0].string_reference,
                &geometry_info);
              if ((flags & SigmaValue) == 0)
                geometry_info.sigma=1.0;
            }
          if (attribute_flag[1] != 0)
            geometry_info.rho=argument_list[1].real_reference;
          if (attribute_flag[2] != 0)
            geometry_info.sigma=argument_list[2].real_reference;
          if (attribute_flag[3] != 0)
            channel=(ChannelType) argument_list[3].integer_reference;
          channel_mask=SetImageChannelMask(image,channel);
          image=SharpenImage(image,geometry_info.rho,geometry_info.sigma,
            exception);
          if (image != (Image *) NULL)
            (void) SetImageChannelMask(image,channel_mask);
          break;
        }
        case 28:  /* Shear */
        {
          if (attribute_flag[0] != 0)
            {
              flags=ParseGeometry(argument_list[0].string_reference,
                &geometry_info);
              if ((flags & SigmaValue) == 0)
                geometry_info.sigma=geometry_info.rho;
            }
          if (attribute_flag[1] != 0)
            geometry_info.rho=argument_list[1].real_reference;
          if (attribute_flag[2] != 0)
            geometry_info.sigma=argument_list[2].real_reference;
          if (attribute_flag[3] != 0)
            QueryColorCompliance(argument_list[3].string_reference,
              AllCompliance,&image->background_color,exception);
          if (attribute_flag[4] != 0)
            QueryColorCompliance(argument_list[4].string_reference,
              AllCompliance,&image->background_color,exception);
          image=ShearImage(image,geometry_info.rho,geometry_info.sigma,
            exception);
          break;
        }
        case 29:  /* Spread */
        {
          PixelInterpolateMethod
            method;

          if (attribute_flag[0] == 0)
            argument_list[0].real_reference=1.0;
          method=UndefinedInterpolatePixel;
          if (attribute_flag[1] != 0)
            method=(PixelInterpolateMethod) argument_list[1].integer_reference;
          image=SpreadImage(image,method,argument_list[0].real_reference,
            exception);
          break;
        }
        case 30:  /* Swirl */
        {
          PixelInterpolateMethod
            method;

          if (attribute_flag[0] == 0)
            argument_list[0].real_reference=50.0;
          method=UndefinedInterpolatePixel;
          if (attribute_flag[1] != 0)
            method=(PixelInterpolateMethod) argument_list[1].integer_reference;
          image=SwirlImage(image,argument_list[0].real_reference,
            method,exception);
          break;
        }
        case 31:  /* Resize */
        case 32:  /* Zoom */
        {
          if (attribute_flag[0] != 0)
            flags=ParseRegionGeometry(image,argument_list[0].string_reference,
              &geometry,exception);
          if (attribute_flag[1] != 0)
            geometry.width=(size_t) argument_list[1].integer_reference;
          if (attribute_flag[2] != 0)
            geometry.height=(size_t) argument_list[2].integer_reference;
          if (attribute_flag[3] == 0)
            argument_list[3].integer_reference=(ssize_t) UndefinedFilter;
          if (attribute_flag[4] != 0)
            SetImageArtifact(image,"filter:support",
              argument_list[4].string_reference);
          image=ResizeImage(image,geometry.width,geometry.height,
            (FilterType) argument_list[3].integer_reference,
            exception);
          break;
        }
        case 33:  /* Annotate */
        {
          DrawInfo
            *draw_info;

          draw_info=CloneDrawInfo(info ? info->image_info : (ImageInfo *) NULL,
            (DrawInfo *) NULL);
          if (attribute_flag[0] != 0)
            {
              char
                *text;

              text=InterpretImageProperties(info ? info->image_info :
                (ImageInfo *) NULL,image,argument_list[0].string_reference,
                exception);
              (void) CloneString(&draw_info->text,text);
              text=DestroyString(text);
            }
          if (attribute_flag[1] != 0)
            (void) CloneString(&draw_info->font,
              argument_list[1].string_reference);
          if (attribute_flag[2] != 0)
            draw_info->pointsize=argument_list[2].real_reference;
          if (attribute_flag[3] != 0)
            (void) CloneString(&draw_info->density,
              argument_list[3].string_reference);
          if (attribute_flag[4] != 0)
            (void) QueryColorCompliance(argument_list[4].string_reference,
              AllCompliance,&draw_info->undercolor,exception);
          if (attribute_flag[5] != 0)
            {
              (void) QueryColorCompliance(argument_list[5].string_reference,
                AllCompliance,&draw_info->stroke,exception);
              if (argument_list[5].image_reference != (Image *) NULL)
                draw_info->stroke_pattern=CloneImage(
                  argument_list[5].image_reference,0,0,MagickTrue,exception);
            }
          if (attribute_flag[6] != 0)
            {
              (void) QueryColorCompliance(argument_list[6].string_reference,
                AllCompliance,&draw_info->fill,exception);
              if (argument_list[6].image_reference != (Image *) NULL)
                draw_info->fill_pattern=CloneImage(
                  argument_list[6].image_reference,0,0,MagickTrue,exception);
            }
          if (attribute_flag[7] != 0)
            {
              (void) CloneString(&draw_info->geometry,
                argument_list[7].string_reference);
              flags=ParsePageGeometry(image,argument_list[7].string_reference,
                &geometry,exception);
              if (((flags & SigmaValue) == 0) && ((flags & XiValue) != 0))
                geometry_info.sigma=geometry_info.xi;
            }
          if (attribute_flag[8] != 0)
            (void) QueryColorCompliance(argument_list[8].string_reference,
              AllCompliance,&draw_info->fill,exception);
          if (attribute_flag[11] != 0)
            draw_info->gravity=(GravityType)
              argument_list[11].integer_reference;
          if (attribute_flag[25] != 0)
            {
              AV
                *av;

              av=(AV *) argument_list[25].array_reference;
              if ((av_len(av) != 3) && (av_len(av) != 5))
                {
                  ThrowPerlException(exception,OptionError,
                    "affine matrix must have 4 or 6 elements",PackageName);
                  goto PerlException;
                }
              draw_info->affine.sx=(double) SvNV(*(av_fetch(av,0,0)));
              draw_info->affine.rx=(double) SvNV(*(av_fetch(av,1,0)));
              draw_info->affine.ry=(double) SvNV(*(av_fetch(av,2,0)));
              draw_info->affine.sy=(double) SvNV(*(av_fetch(av,3,0)));
              if (fabs(draw_info->affine.sx*draw_info->affine.sy-
                  draw_info->affine.rx*draw_info->affine.ry) < MagickEpsilon)
                {
                  ThrowPerlException(exception,OptionError,
                    "affine matrix is singular",PackageName);
                   goto PerlException;
                }
              if (av_len(av) == 5)
                {
                  draw_info->affine.tx=(double) SvNV(*(av_fetch(av,4,0)));
                  draw_info->affine.ty=(double) SvNV(*(av_fetch(av,5,0)));
                }
            }
          for (j=12; j < 17; j++)
          {
            if (attribute_flag[j] == 0)
              continue;
            value=argument_list[j].string_reference;
            angle=argument_list[j].real_reference;
            current=draw_info->affine;
            GetAffineMatrix(&affine);
            switch (j)
            {
              case 12:
              {
                /*
                  Translate.
                */
                flags=ParseGeometry(value,&geometry_info);
                affine.tx=geometry_info.xi;
                affine.ty=geometry_info.psi;
                if ((flags & PsiValue) == 0)
                  affine.ty=affine.tx;
                break;
              }
              case 13:
              {
                /*
                  Scale.
                */
                flags=ParseGeometry(value,&geometry_info);
                affine.sx=geometry_info.rho;
                affine.sy=geometry_info.sigma;
                if ((flags & SigmaValue) == 0)
                  affine.sy=affine.sx;
                break;
              }
              case 14:
              {
                /*
                  Rotate.
                */
                if (angle == 0.0)
                  break;
                affine.sx=cos(DegreesToRadians(fmod(angle,360.0)));
                affine.rx=sin(DegreesToRadians(fmod(angle,360.0)));
                affine.ry=(-sin(DegreesToRadians(fmod(angle,360.0))));
                affine.sy=cos(DegreesToRadians(fmod(angle,360.0)));
                break;
              }
              case 15:
              {
                /*
                  SkewX.
                */
                affine.ry=tan(DegreesToRadians(fmod(angle,360.0)));
                break;
              }
              case 16:
              {
                /*
                  SkewY.
                */
                affine.rx=tan(DegreesToRadians(fmod(angle,360.0)));
                break;
              }
            }
            draw_info->affine.sx=current.sx*affine.sx+current.ry*affine.rx;
            draw_info->affine.rx=current.rx*affine.sx+current.sy*affine.rx;
            draw_info->affine.ry=current.sx*affine.ry+current.ry*affine.sy;
            draw_info->affine.sy=current.rx*affine.ry+current.sy*affine.sy;
            draw_info->affine.tx=current.sx*affine.tx+current.ry*affine.ty+
              current.tx;
            draw_info->affine.ty=current.rx*affine.tx+current.sy*affine.ty+
              current.ty;
          }
          if (attribute_flag[9] == 0)
            argument_list[9].real_reference=0.0;
          if (attribute_flag[10] == 0)
            argument_list[10].real_reference=0.0;
          if ((attribute_flag[9] != 0) || (attribute_flag[10] != 0))
            {
              char
                geometry[MagickPathExtent];

              (void) FormatLocaleString(geometry,MagickPathExtent,"%+f%+f",
                (double) argument_list[9].real_reference+draw_info->affine.tx,
                (double) argument_list[10].real_reference+draw_info->affine.ty);
              (void) CloneString(&draw_info->geometry,geometry);
            }
          if (attribute_flag[17] != 0)
            draw_info->stroke_width=(size_t) argument_list[17].real_reference;
          if (attribute_flag[18] != 0)
            {
              draw_info->text_antialias=argument_list[18].integer_reference != 0 ?
                MagickTrue : MagickFalse;
              draw_info->stroke_antialias=draw_info->text_antialias;
            }
          if (attribute_flag[19] != 0)
            (void) CloneString(&draw_info->family,
              argument_list[19].string_reference);
          if (attribute_flag[20] != 0)
            draw_info->style=(StyleType) argument_list[20].integer_reference;
          if (attribute_flag[21] != 0)
            draw_info->stretch=(StretchType) argument_list[21].integer_reference;
          if (attribute_flag[22] != 0)
            draw_info->weight=(size_t) argument_list[22].integer_reference;
          if (attribute_flag[23] != 0)
            draw_info->align=(AlignType) argument_list[23].integer_reference;
          if (attribute_flag[24] != 0)
            (void) CloneString(&draw_info->encoding,
              argument_list[24].string_reference);
          if (attribute_flag[25] != 0)
            draw_info->fill_pattern=CloneImage(
              argument_list[25].image_reference,0,0,MagickTrue,exception);
          if (attribute_flag[26] != 0)
            draw_info->fill_pattern=CloneImage(
              argument_list[26].image_reference,0,0,MagickTrue,exception);
          if (attribute_flag[27] != 0)
            draw_info->stroke_pattern=CloneImage(
              argument_list[27].image_reference,0,0,MagickTrue,exception);
          if (attribute_flag[29] != 0)
            draw_info->kerning=argument_list[29].real_reference;
          if (attribute_flag[30] != 0)
            draw_info->interline_spacing=argument_list[30].real_reference;
          if (attribute_flag[31] != 0)
            draw_info->interword_spacing=argument_list[31].real_reference;
          if (attribute_flag[32] != 0)
            draw_info->direction=(DirectionType)
              argument_list[32].integer_reference;
          if (attribute_flag[33] != 0)
            draw_info->decorate=(DecorationType)
              argument_list[33].integer_reference;
          if (attribute_flag[34] != 0)
            draw_info->word_break=(WordBreakType)
              argument_list[34].integer_reference;
          (void) AnnotateImage(image,draw_info,exception);
          draw_info=DestroyDrawInfo(draw_info);
          break;
        }
        case 34:  /* ColorFloodfill */
        {
          DrawInfo
            *draw_info;

          MagickBooleanType
            invert;

          PixelInfo
            target;

          draw_info=CloneDrawInfo(info ? info->image_info :
            (ImageInfo *) NULL,(DrawInfo *) NULL);
          if (attribute_flag[0] != 0)
            flags=ParsePageGeometry(image,argument_list[0].string_reference,
              &geometry,exception);
          if (attribute_flag[1] != 0)
            geometry.x=argument_list[1].integer_reference;
          if (attribute_flag[2] != 0)
            geometry.y=argument_list[2].integer_reference;
          if (attribute_flag[3] != 0)
            (void) QueryColorCompliance(argument_list[3].string_reference,
              AllCompliance,&draw_info->fill,exception);
          (void) GetOneVirtualPixelInfo(image,UndefinedVirtualPixelMethod,
            geometry.x,geometry.y,&target,exception);
          invert=MagickFalse;
          if (attribute_flag[4] != 0)
            {
              QueryColorCompliance(argument_list[4].string_reference,
                AllCompliance,&target,exception);
              invert=MagickTrue;
            }
          if (attribute_flag[5] != 0)
            image->fuzz=StringToDoubleInterval(
              argument_list[5].string_reference,(double) QuantumRange+1.0);
          if (attribute_flag[6] != 0)
            invert=(MagickBooleanType) argument_list[6].integer_reference;
          (void) FloodfillPaintImage(image,draw_info,&target,geometry.x,
            geometry.y,invert,exception);
          draw_info=DestroyDrawInfo(draw_info);
          break;
        }
        case 35:  /* Composite */
        {
          char
            composite_geometry[MagickPathExtent];

          Image
            *composite_image,
            *rotate_image;

          MagickBooleanType
            clip_to_self;

          compose=OverCompositeOp;
          if (attribute_flag[0] != 0)
            composite_image=argument_list[0].image_reference;
          else
            {
              ThrowPerlException(exception,OptionError,
                "CompositeImageRequired",PackageName);
              goto PerlException;
            }
          /*
            Parameter Handling used for BOTH normal and tiled composition.
          */
          if (attribute_flag[1] != 0) /* compose */
            compose=(CompositeOperator) argument_list[1].integer_reference;
          if (attribute_flag[6] != 0) /* opacity  */
            {
              if (compose != DissolveCompositeOp)
                (void) SetImageAlpha(composite_image,(Quantum)
                  StringToDoubleInterval(argument_list[6].string_reference,
                  (double) QuantumRange+1.0),exception);
              else
                {
                  CacheView
                    *composite_view;

                  double
                    opacity;

                  MagickBooleanType
                    sync;

                  Quantum
                    *q;

                  ssize_t
                    x,
                    y;

                  /*
                    Handle dissolve composite operator (patch by
                    Kevin A. McGrail).
                  */
                  (void) CloneString(&image->geometry,
                    argument_list[6].string_reference);
                  opacity=(Quantum) StringToDoubleInterval(
                    argument_list[6].string_reference,(double) QuantumRange+
                    1.0);
                  if (composite_image->alpha_trait != UndefinedPixelTrait)
                    (void) SetImageAlpha(composite_image,OpaqueAlpha,exception);
                  composite_view=AcquireAuthenticCacheView(composite_image,exception);
                  for (y=0; y < (ssize_t) composite_image->rows ; y++)
                  {
                    q=GetCacheViewAuthenticPixels(composite_view,0,y,
                      composite_image->columns,1,exception);
                    for (x=0; x < (ssize_t) composite_image->columns; x++)
                    {
                      if (GetPixelAlpha(image,q) == OpaqueAlpha)
                        SetPixelAlpha(composite_image,ClampToQuantum(opacity),
                          q);
                      q+=GetPixelChannels(composite_image);
                    }
                    sync=SyncCacheViewAuthenticPixels(composite_view,exception);
                    if (sync == MagickFalse)
                      break;
                  }
                  composite_view=DestroyCacheView(composite_view);
                }
            }
          if (attribute_flag[9] != 0)    /* "color=>" */
            QueryColorCompliance(argument_list[9].string_reference,
              AllCompliance,&composite_image->background_color,exception);
          if (attribute_flag[12] != 0) /* "interpolate=>" */
            image->interpolate=(PixelInterpolateMethod)
              argument_list[12].integer_reference;
          if (attribute_flag[13] != 0)   /* "args=>" */
            (void) SetImageArtifact(image,"compose:args",
              argument_list[13].string_reference);
          if (attribute_flag[14] != 0)   /* "blend=>"  depreciated */
            (void) SetImageArtifact(image,"compose:args",
              argument_list[14].string_reference);
          clip_to_self=MagickTrue;
          if (attribute_flag[15] != 0)
            clip_to_self=(MagickBooleanType)
              argument_list[15].integer_reference;
          /*
            Tiling Composition (with orthogonal rotate).
          */
          rotate_image=(Image *) NULL;
          if (attribute_flag[8] != 0)   /* "rotate=>" */
            {
               /*
                 Rotate image.
               */
               rotate_image=RotateImage(composite_image,
                 argument_list[8].real_reference,exception);
               if (rotate_image == (Image *) NULL)
                 break;
            }
          if ((attribute_flag[7] != 0) &&
              (argument_list[7].integer_reference != 0)) /* tile */
            {
              ssize_t
                x,
                y;

              /*
                Tile the composite image.
              */
             for (y=0; y < (ssize_t) image->rows; y+=(ssize_t) composite_image->rows)
                for (x=0; x < (ssize_t) image->columns; x+=(ssize_t) composite_image->columns)
                {
                  if (attribute_flag[8] != 0) /* rotate */
                    (void) CompositeImage(image,rotate_image,compose,
                      MagickTrue,x,y,exception);
                  else
                    (void) CompositeImage(image,composite_image,compose,
                      MagickTrue,x,y,exception);
                }
              if (attribute_flag[8] != 0) /* rotate */
                rotate_image=DestroyImage(rotate_image);
              break;
            }
          /*
            Parameter Handling used ONLY for normal composition.
          */
          if (attribute_flag[5] != 0) /* gravity */
            image->gravity=(GravityType) argument_list[5].integer_reference;
          if (attribute_flag[2] != 0) /* geometry offset */
            {
              SetGeometry(image,&geometry);
              (void) ParseAbsoluteGeometry(argument_list[2].string_reference,
                &geometry);
              GravityAdjustGeometry(image->columns,image->rows,image->gravity,
                &geometry);
            }
          if (attribute_flag[3] != 0) /* x offset */
            geometry.x=argument_list[3].integer_reference;
          if (attribute_flag[4] != 0) /* y offset */
            geometry.y=argument_list[4].integer_reference;
          if (attribute_flag[10] != 0) /* mask */
            {
              if ((image->compose == DisplaceCompositeOp) ||
                  (image->compose == DistortCompositeOp))
                {
                  /*
                    Merge Y displacement into X displacement image.
                  */
                  composite_image=CloneImage(composite_image,0,0,MagickTrue,
                    exception);
                  (void) CompositeImage(composite_image,
                    argument_list[10].image_reference,CopyGreenCompositeOp,
                    clip_to_self,0,0,exception);
                  (void) SetImageColorspace(composite_image,sRGBColorspace,
                    exception);

                }
              else
                {
                  Image
                    *mask_image;

                  /*
                    Set a blending mask for the composition.
                  */
                  mask_image=CloneImage(argument_list[10].image_reference,0,0,
                    MagickTrue,exception);
                  (void) SetImageMask(composite_image,ReadPixelMask,mask_image,
                    exception);
                  mask_image=DestroyImage(mask_image);
                }
            }
          if (attribute_flag[11] != 0) /* channel */
            channel=(ChannelType) argument_list[11].integer_reference;
          /*
            Composite two images (normal composition).
          */
          (void) FormatLocaleString(composite_geometry,MagickPathExtent,
            "%.20gx%.20g%+.20g%+.20g",(double) composite_image->columns,
            (double) composite_image->rows,(double) geometry.x,(double)
            geometry.y);
          flags=ParseGravityGeometry(image,composite_geometry,&geometry,
            exception);
          channel_mask=SetImageChannelMask(image,channel);
          if (attribute_flag[8] == 0) /* no rotate */
            CompositeImage(image,composite_image,compose,clip_to_self,
              geometry.x,geometry.y,exception);
          else
            {
              /*
                Position adjust rotated image then composite.
              */
              geometry.x-=(ssize_t) (rotate_image->columns-
                composite_image->columns)/2;
              geometry.y-=(ssize_t) (rotate_image->rows-
                composite_image->rows)/2;
              CompositeImage(image,rotate_image,compose,clip_to_self,geometry.x,
                geometry.y,exception);
              rotate_image=DestroyImage(rotate_image);
            }
          if (attribute_flag[10] != 0) /* mask */
            {
              if ((image->compose == DisplaceCompositeOp) ||
                  (image->compose == DistortCompositeOp))
                composite_image=DestroyImage(composite_image);
              else
                (void) SetImageMask(image,ReadPixelMask,(Image *) NULL,
                  exception);
            }
          (void) SetImageChannelMask(image,channel_mask);
          break;
        }
        case 36:  /* Contrast */
        {
          if (attribute_flag[0] == 0)
            argument_list[0].integer_reference=0;
          (void) ContrastImage(image,argument_list[0].integer_reference != 0 ?
            MagickTrue : MagickFalse,exception);
          break;
        }
        case 37:  /* CycleColormap */
        {
          if (attribute_flag[0] == 0)
            argument_list[0].integer_reference=6;
          (void) CycleColormapImage(image,argument_list[0].integer_reference,
            exception);
          break;
        }
        case 38:  /* Draw */
        {
          DrawInfo
            *draw_info;

          draw_info=CloneDrawInfo(info ? info->image_info : (ImageInfo *) NULL,
            (DrawInfo *) NULL);
          (void) CloneString(&draw_info->primitive,"point");
          if (attribute_flag[0] != 0)
            {
              if (argument_list[0].integer_reference < 0)
                (void) CloneString(&draw_info->primitive,
                  argument_list[0].string_reference);
              else
                (void) CloneString(&draw_info->primitive,CommandOptionToMnemonic(
                  MagickPrimitiveOptions,argument_list[0].integer_reference));
            }
          if (attribute_flag[1] != 0)
            {
              if (LocaleCompare(draw_info->primitive,"path") == 0)
                {
                  (void) ConcatenateString(&draw_info->primitive," '");
                  ConcatenateString(&draw_info->primitive,
                    argument_list[1].string_reference);
                  (void) ConcatenateString(&draw_info->primitive,"'");
                }
              else
                {
                  (void) ConcatenateString(&draw_info->primitive," ");
                  ConcatenateString(&draw_info->primitive,
                    argument_list[1].string_reference);
                }
            }
          if (attribute_flag[2] != 0)
            {
              (void) ConcatenateString(&draw_info->primitive," ");
              (void) ConcatenateString(&draw_info->primitive,
                CommandOptionToMnemonic(MagickMethodOptions,
                argument_list[2].integer_reference));
            }
          if (attribute_flag[3] != 0)
            {
              (void) QueryColorCompliance(argument_list[3].string_reference,
                AllCompliance,&draw_info->stroke,exception);
              if (argument_list[3].image_reference != (Image *) NULL)
                draw_info->stroke_pattern=CloneImage(
                  argument_list[3].image_reference,0,0,MagickTrue,exception);
            }
          if (attribute_flag[4] != 0)
            {
              (void) QueryColorCompliance(argument_list[4].string_reference,
                AllCompliance,&draw_info->fill,exception);
              if (argument_list[4].image_reference != (Image *) NULL)
                draw_info->fill_pattern=CloneImage(
                  argument_list[4].image_reference,0,0,MagickTrue,exception);
            }
          if (attribute_flag[5] != 0)
            draw_info->stroke_width=(size_t) argument_list[5].real_reference;
          if (attribute_flag[6] != 0)
            (void) CloneString(&draw_info->font,
              argument_list[6].string_reference);
          if (attribute_flag[7] != 0)
            (void) QueryColorCompliance(argument_list[7].string_reference,
              AllCompliance,&draw_info->border_color,exception);
          if (attribute_flag[8] != 0)
            draw_info->affine.tx=argument_list[8].real_reference;
          if (attribute_flag[9] != 0)
            draw_info->affine.ty=argument_list[9].real_reference;
          if (attribute_flag[20] != 0)
            {
              AV
                *av;

              av=(AV *) argument_list[20].array_reference;
              if ((av_len(av) != 3) && (av_len(av) != 5))
                {
                  ThrowPerlException(exception,OptionError,
                    "affine matrix must have 4 or 6 elements",PackageName);
                  goto PerlException;
                }
              draw_info->affine.sx=(double) SvNV(*(av_fetch(av,0,0)));
              draw_info->affine.rx=(double) SvNV(*(av_fetch(av,1,0)));
              draw_info->affine.ry=(double) SvNV(*(av_fetch(av,2,0)));
              draw_info->affine.sy=(double) SvNV(*(av_fetch(av,3,0)));
              if (fabs(draw_info->affine.sx*draw_info->affine.sy-
                  draw_info->affine.rx*draw_info->affine.ry) < MagickEpsilon)
                {
                  ThrowPerlException(exception,OptionError,
                    "affine matrix is singular",PackageName);
                   goto PerlException;
                }
              if (av_len(av) == 5)
                {
                  draw_info->affine.tx=(double) SvNV(*(av_fetch(av,4,0)));
                  draw_info->affine.ty=(double) SvNV(*(av_fetch(av,5,0)));
                }
            }
          for (j=10; j < 15; j++)
          {
            if (attribute_flag[j] == 0)
              continue;
            value=argument_list[j].string_reference;
            angle=argument_list[j].real_reference;
            current=draw_info->affine;
            GetAffineMatrix(&affine);
            switch (j)
            {
              case 10:
              {
                /*
                  Translate.
                */
                flags=ParseGeometry(value,&geometry_info);
                affine.tx=geometry_info.xi;
                affine.ty=geometry_info.psi;
                if ((flags & PsiValue) == 0)
                  affine.ty=affine.tx;
                break;
              }
              case 11:
              {
                /*
                  Scale.
                */
                flags=ParseGeometry(value,&geometry_info);
                affine.sx=geometry_info.rho;
                affine.sy=geometry_info.sigma;
                if ((flags & SigmaValue) == 0)
                  affine.sy=affine.sx;
                break;
              }
              case 12:
              {
                /*
                  Rotate.
                */
                if (angle == 0.0)
                  break;
                affine.sx=cos(DegreesToRadians(fmod(angle,360.0)));
                affine.rx=sin(DegreesToRadians(fmod(angle,360.0)));
                affine.ry=(-sin(DegreesToRadians(fmod(angle,360.0))));
                affine.sy=cos(DegreesToRadians(fmod(angle,360.0)));
                break;
              }
              case 13:
              {
                /*
                  SkewX.
                */
                affine.ry=tan(DegreesToRadians(fmod(angle,360.0)));
                break;
              }
              case 14:
              {
                /*
                  SkewY.
                */
                affine.rx=tan(DegreesToRadians(fmod(angle,360.0)));
                break;
              }
            }
            draw_info->affine.sx=current.sx*affine.sx+current.ry*affine.rx;
            draw_info->affine.rx=current.rx*affine.sx+current.sy*affine.rx;
            draw_info->affine.ry=current.sx*affine.ry+current.ry*affine.sy;
            draw_info->affine.sy=current.rx*affine.ry+current.sy*affine.sy;
            draw_info->affine.tx=
              current.sx*affine.tx+current.ry*affine.ty+current.tx;
            draw_info->affine.ty=
              current.rx*affine.tx+current.sy*affine.ty+current.ty;
          }
          if (attribute_flag[15] != 0)
            draw_info->fill_pattern=CloneImage(
              argument_list[15].image_reference,0,0,MagickTrue,exception);
          if (attribute_flag[16] != 0)
            draw_info->pointsize=argument_list[16].real_reference;
          if (attribute_flag[17] != 0)
            {
              draw_info->stroke_antialias=argument_list[17].integer_reference != 0 ? MagickTrue : MagickFalse;
              draw_info->text_antialias=draw_info->stroke_antialias;
            }
          if (attribute_flag[18] != 0)
            (void) CloneString(&draw_info->density,
              argument_list[18].string_reference);
          if (attribute_flag[19] != 0)
            draw_info->stroke_width=(size_t) argument_list[19].real_reference;
          if (attribute_flag[21] != 0)
            draw_info->dash_offset=argument_list[21].real_reference;
          if (attribute_flag[22] != 0)
            {
              AV
                *av;

              av=(AV *) argument_list[22].array_reference;
              draw_info->dash_pattern=(double *) AcquireQuantumMemory(
                (size_t) av_len(av)+2UL,sizeof(*draw_info->dash_pattern));
              if (draw_info->dash_pattern != (double *) NULL)
                {
                  for (i=0; i <= av_len(av); i++)
                    draw_info->dash_pattern[i]=(double)
                      SvNV(*(av_fetch(av,i,0)));
                  draw_info->dash_pattern[i]=0.0;
                }
            }
          if (attribute_flag[23] != 0)
            image->interpolate=(PixelInterpolateMethod)
              argument_list[23].integer_reference;
          if ((attribute_flag[24] != 0) &&
              (draw_info->fill_pattern != (Image *) NULL))
            flags=ParsePageGeometry(draw_info->fill_pattern,
              argument_list[24].string_reference,
              &draw_info->fill_pattern->tile_offset,exception);
          if (attribute_flag[25] != 0)
            {
              (void) ConcatenateString(&draw_info->primitive," '");
              (void) ConcatenateString(&draw_info->primitive,
                argument_list[25].string_reference);
              (void) ConcatenateString(&draw_info->primitive,"'");
            }
          if (attribute_flag[26] != 0)
            draw_info->fill_pattern=CloneImage(
              argument_list[26].image_reference,0,0,MagickTrue,exception);
          if (attribute_flag[27] != 0)
            draw_info->stroke_pattern=CloneImage(
              argument_list[27].image_reference,0,0,MagickTrue,exception);
          if (attribute_flag[28] != 0)
            (void) CloneString(&draw_info->primitive,
              argument_list[28].string_reference);
          if (attribute_flag[29] != 0)
            draw_info->kerning=argument_list[29].real_reference;
          if (attribute_flag[30] != 0)
            draw_info->interline_spacing=argument_list[30].real_reference;
          if (attribute_flag[31] != 0)
            draw_info->interword_spacing=argument_list[31].real_reference;
          if (attribute_flag[32] != 0)
            draw_info->direction=(DirectionType)
              argument_list[32].integer_reference;
          if (attribute_flag[33] != 0)
            draw_info->word_break=(WordBreakType)
              argument_list[33].integer_reference;
          (void) DrawImage(image,draw_info,exception);
          draw_info=DestroyDrawInfo(draw_info);
          break;
        }
        case 39:  /* Equalize */
        {
          if (attribute_flag[0] != 0)
            channel=(ChannelType) argument_list[0].integer_reference;
          channel_mask=SetImageChannelMask(image,channel);
          (void) EqualizeImage(image,exception);
          (void) SetImageChannelMask(image,channel_mask);
          break;
        }
        case 40:  /* Gamma */
        {
          if (attribute_flag[1] != 0)
            channel=(ChannelType) argument_list[1].integer_reference;
          if (attribute_flag[2] == 0)
            argument_list[2].real_reference=1.0;
          if (attribute_flag[3] == 0)
            argument_list[3].real_reference=1.0;
          if (attribute_flag[4] == 0)
            argument_list[4].real_reference=1.0;
          if (attribute_flag[0] == 0)
            {
              (void) FormatLocaleString(message,MagickPathExtent,
                "%.20g,%.20g,%.20g",(double) argument_list[2].real_reference,
                (double) argument_list[3].real_reference,
                (double) argument_list[4].real_reference);
              argument_list[0].string_reference=message;
            }
          (void) GammaImage(image,StringToDouble(
            argument_list[0].string_reference,(char **) NULL),exception);
          break;
        }
        case 41:  /* Map */
        {
          QuantizeInfo
            *quantize_info;

          if (attribute_flag[0] == 0)
            {
              ThrowPerlException(exception,OptionError,"MapImageRequired",
                PackageName);
              goto PerlException;
            }
          quantize_info=AcquireQuantizeInfo(info->image_info);
          if (attribute_flag[1] != 0)
            quantize_info->dither_method=(DitherMethod)
              argument_list[1].integer_reference;
          (void) RemapImages(quantize_info,image,
            argument_list[0].image_reference,exception);
          quantize_info=DestroyQuantizeInfo(quantize_info);
          break;
        }
        case 42:  /* MatteFloodfill */
        {
          DrawInfo
            *draw_info;

          MagickBooleanType
            invert;

          PixelInfo
            target;

          draw_info=CloneDrawInfo(info ? info->image_info : (ImageInfo *) NULL,
            (DrawInfo *) NULL);
          if (attribute_flag[0] != 0)
            flags=ParsePageGeometry(image,argument_list[0].string_reference,
              &geometry,exception);
          if (attribute_flag[1] != 0)
            geometry.x=argument_list[1].integer_reference;
          if (attribute_flag[2] != 0)
            geometry.y=argument_list[2].integer_reference;
          if (image->alpha_trait == UndefinedPixelTrait)
            (void) SetImageAlpha(image,OpaqueAlpha,exception);
          (void) GetOneVirtualPixelInfo(image,UndefinedVirtualPixelMethod,
            geometry.x,geometry.y,&target,exception);
          if (attribute_flag[4] != 0)
            QueryColorCompliance(argument_list[4].string_reference,
              AllCompliance,&target,exception);
          if (attribute_flag[3] != 0)
            target.alpha=StringToDoubleInterval(
              argument_list[3].string_reference,(double) (double) QuantumRange+
              1.0);
          if (attribute_flag[5] != 0)
            image->fuzz=StringToDoubleInterval(
              argument_list[5].string_reference,(double) QuantumRange+1.0);
          invert=MagickFalse;
          if (attribute_flag[6] != 0)
            invert=(MagickBooleanType) argument_list[6].integer_reference;
          channel_mask=SetImageChannelMask(image,AlphaChannel);
          (void) FloodfillPaintImage(image,draw_info,&target,geometry.x,
            geometry.y,invert,exception);
          (void) SetImageChannelMask(image,channel_mask);
          draw_info=DestroyDrawInfo(draw_info);
          break;
        }
        case 43:  /* Modulate */
        {
          char
            modulate[MagickPathExtent];

          geometry_info.rho=100.0;
          geometry_info.sigma=100.0;
          geometry_info.xi=100.0;
          if (attribute_flag[0] != 0)
            (void)ParseGeometry(argument_list[0].string_reference,
              &geometry_info);
          if (attribute_flag[1] != 0)
            geometry_info.xi=argument_list[1].real_reference;
          if (attribute_flag[2] != 0)
            geometry_info.sigma=argument_list[2].real_reference;
          if (attribute_flag[3] != 0)
            {
              geometry_info.sigma=argument_list[3].real_reference;
              SetImageArtifact(image,"modulate:colorspace","HWB");
            }
          if (attribute_flag[4] != 0)
            {
              geometry_info.rho=argument_list[4].real_reference;
              SetImageArtifact(image,"modulate:colorspace","HSB");
            }
          if (attribute_flag[5] != 0)
            {
              geometry_info.sigma=argument_list[5].real_reference;
              SetImageArtifact(image,"modulate:colorspace","HSL");
            }
          if (attribute_flag[6] != 0)
            {
              geometry_info.rho=argument_list[6].real_reference;
              SetImageArtifact(image,"modulate:colorspace","HWB");
            }
          (void) FormatLocaleString(modulate,MagickPathExtent,"%.20g,%.20g,%.20g",
            geometry_info.rho,geometry_info.sigma,geometry_info.xi);
          (void) ModulateImage(image,modulate,exception);
          break;
        }
        case 44:  /* Negate */
        {
          if (attribute_flag[0] == 0)
            argument_list[0].integer_reference=0;
          if (attribute_flag[1] != 0)
            channel=(ChannelType) argument_list[1].integer_reference;
          channel_mask=SetImageChannelMask(image,channel);
          (void) NegateImage(image,argument_list[0].integer_reference != 0 ?
            MagickTrue : MagickFalse,exception);
          (void) SetImageChannelMask(image,channel_mask);
          break;
        }
        case 45:  /* Normalize */
        {
          if (attribute_flag[0] != 0)
            channel=(ChannelType) argument_list[0].integer_reference;
          channel_mask=SetImageChannelMask(image,channel);
          NormalizeImage(image,exception);
          (void) SetImageChannelMask(image,channel_mask);
          break;
        }
        case 46:  /* NumberColors */
          break;
        case 47:  /* Opaque */
        {
          MagickBooleanType
            invert;

          PixelInfo
            fill_color,
            target;

          (void) QueryColorCompliance("none",AllCompliance,&target,
             exception);
          (void) QueryColorCompliance("none",AllCompliance,&fill_color,
            exception);
          if (attribute_flag[0] != 0)
            (void) QueryColorCompliance(argument_list[0].string_reference,
              AllCompliance,&target,exception);
          if (attribute_flag[1] != 0)
            (void) QueryColorCompliance(argument_list[1].string_reference,
              AllCompliance,&fill_color,exception);
          if (attribute_flag[2] != 0)
            image->fuzz=StringToDoubleInterval(
              argument_list[2].string_reference,(double) QuantumRange+1.0);
          if (attribute_flag[3] != 0)
            channel=(ChannelType) argument_list[3].integer_reference;
          invert=MagickFalse;
          if (attribute_flag[4] != 0)
            invert=(MagickBooleanType) argument_list[4].integer_reference;
          channel_mask=SetImageChannelMask(image,channel);
          (void) OpaquePaintImage(image,&target,&fill_color,invert,exception);
          (void) SetImageChannelMask(image,channel_mask);
          break;
        }
        case 48:  /* Quantize */
        {
          QuantizeInfo
            *quantize_info;

          quantize_info=AcquireQuantizeInfo(info->image_info);
          if (attribute_flag[0] != 0)
            quantize_info->number_colors=(size_t)
              argument_list[0].integer_reference;
          if (attribute_flag[1] != 0)
            quantize_info->tree_depth=(size_t)
              argument_list[1].integer_reference;
          if (attribute_flag[2] != 0)
            quantize_info->colorspace=(ColorspaceType)
              argument_list[2].integer_reference;
          if (attribute_flag[3] != 0)
            quantize_info->dither_method=(DitherMethod)
              argument_list[3].integer_reference;
          if (attribute_flag[4] != 0)
            quantize_info->measure_error=
              argument_list[4].integer_reference != 0 ? MagickTrue : MagickFalse;
          if (attribute_flag[6] != 0)
            (void) QueryColorCompliance(argument_list[6].string_reference,
              AllCompliance,&image->transparent_color,exception);
          if (attribute_flag[7] != 0)
            quantize_info->dither_method=(DitherMethod)
              argument_list[7].integer_reference;
          if (attribute_flag[5] && argument_list[5].integer_reference)
            (void) QuantizeImages(quantize_info,image,exception);
          else
            if ((image->storage_class == DirectClass) ||
               (image->colors > quantize_info->number_colors) ||
               (quantize_info->colorspace == GRAYColorspace))
             (void) QuantizeImage(quantize_info,image,exception);
           else
             CompressImageColormap(image,exception);
          quantize_info=DestroyQuantizeInfo(quantize_info);
          break;
        }
        case 49:  /* Raise */
        {
          if (attribute_flag[0] != 0)
            flags=ParsePageGeometry(image,argument_list[0].string_reference,
              &geometry,exception);
          if (attribute_flag[1] != 0)
            geometry.width=(size_t) argument_list[1].integer_reference;
          if (attribute_flag[2] != 0)
            geometry.height=(size_t) argument_list[2].integer_reference;
          if (attribute_flag[3] == 0)
            argument_list[3].integer_reference=1;
          (void) RaiseImage(image,&geometry,
            argument_list[3].integer_reference != 0 ? MagickTrue : MagickFalse,
            exception);
          break;
        }
        case 50:  /* Segment */
        {
          ColorspaceType
            colorspace;

          double
            cluster_threshold,
            smoothing_threshold;

          MagickBooleanType
            verbose;

          cluster_threshold=1.0;
          smoothing_threshold=1.5;
          colorspace=sRGBColorspace;
          verbose=MagickFalse;
          if (attribute_flag[0] != 0)
            {
              flags=ParseGeometry(argument_list[0].string_reference,
                &geometry_info);
              cluster_threshold=geometry_info.rho;
              if (flags & SigmaValue)
                smoothing_threshold=geometry_info.sigma;
            }
          if (attribute_flag[1] != 0)
            cluster_threshold=argument_list[1].real_reference;
          if (attribute_flag[2] != 0)
            smoothing_threshold=argument_list[2].real_reference;
          if (attribute_flag[3] != 0)
            colorspace=(ColorspaceType) argument_list[3].integer_reference;
          if (attribute_flag[4] != 0)
            verbose=argument_list[4].integer_reference != 0 ?
              MagickTrue : MagickFalse;
          (void) SegmentImage(image,colorspace,verbose,cluster_threshold,
            smoothing_threshold,exception);
          break;
        }
        case 51:  /* Signature */
        {
          (void) SignatureImage(image,exception);
          break;
        }
        case 52:  /* Solarize */
        {
          geometry_info.rho=QuantumRange/2.0;
          if (attribute_flag[0] != 0)
            flags=ParseGeometry(argument_list[0].string_reference,
              &geometry_info);
          if (attribute_flag[1] != 0)
            geometry_info.rho=StringToDoubleInterval(
              argument_list[1].string_reference,(double) QuantumRange+1.0);
          (void) SolarizeImage(image,geometry_info.rho,exception);
          break;
        }
        case 53:  /* Sync */
        {
          (void) SyncImage(image,exception);
          break;
        }
        case 54:  /* Texture */
        {
          if (attribute_flag[0] == 0)
            break;
          TextureImage(image,argument_list[0].image_reference,exception);
          break;
        }
        case 55:  /* Evaluate */
        {
          MagickEvaluateOperator
            op;

          op=SetEvaluateOperator;
          if (attribute_flag[0] == MagickFalse)
            argument_list[0].real_reference=0.0;
          if (attribute_flag[1] != MagickFalse)
            op=(MagickEvaluateOperator) argument_list[1].integer_reference;
          if (attribute_flag[2] != MagickFalse)
            channel=(ChannelType) argument_list[2].integer_reference;
          channel_mask=SetImageChannelMask(image,channel);
          (void) EvaluateImage(image,op,argument_list[0].real_reference,
            exception);
          (void) SetImageChannelMask(image,channel_mask);
          break;
        }
        case 56:  /* Transparent */
        {
          double
            opacity;

          MagickBooleanType
            invert;

          PixelInfo
            target;

          (void) QueryColorCompliance("none",AllCompliance,&target,
            exception);
          if (attribute_flag[0] != 0)
            (void) QueryColorCompliance(argument_list[0].string_reference,
              AllCompliance,&target,exception);
          opacity=TransparentAlpha;
          if (attribute_flag[1] != 0)
            opacity=StringToDoubleInterval(argument_list[1].string_reference,
              (double) QuantumRange+1.0);
          if (attribute_flag[2] != 0)
            image->fuzz=StringToDoubleInterval(
              argument_list[2].string_reference,(double) QuantumRange+1.0);
          if (attribute_flag[3] == 0)
            argument_list[3].integer_reference=0;
          invert=MagickFalse;
          if (attribute_flag[3] != 0)
            invert=(MagickBooleanType) argument_list[3].integer_reference;
          (void) TransparentPaintImage(image,&target,ClampToQuantum(opacity),
            invert,exception);
          break;
        }
        case 57:  /* Threshold */
        {
          double
            threshold;

          if (attribute_flag[0] == 0)
            argument_list[0].string_reference="50%";
          if (attribute_flag[1] != 0)
            channel=(ChannelType) argument_list[1].integer_reference;
          threshold=StringToDoubleInterval(argument_list[0].string_reference,
            (double) QuantumRange+1.0);
          channel_mask=SetImageChannelMask(image,channel);
          (void) BilevelImage(image,threshold,exception);
          (void) SetImageChannelMask(image,channel_mask);
          break;
        }
        case 58:  /* Charcoal */
        {
          if (attribute_flag[0] != 0)
            {
              flags=ParseGeometry(argument_list[0].string_reference,
                &geometry_info);
              if ((flags & SigmaValue) == 0)
                geometry_info.sigma=1.0;
            }
          if (attribute_flag[1] != 0)
            geometry_info.rho=argument_list[1].real_reference;
          if (attribute_flag[2] != 0)
            geometry_info.sigma=argument_list[2].real_reference;
          image=CharcoalImage(image,geometry_info.rho,geometry_info.sigma,
            exception);
          break;
        }
        case 59:  /* Trim */
        {
          if (attribute_flag[0] != 0)
            image->fuzz=StringToDoubleInterval(
              argument_list[0].string_reference,(double) QuantumRange+1.0);
          image=TrimImage(image,exception);
          break;
        }
        case 60:  /* Wave */
        {
          PixelInterpolateMethod
            method;

          if (attribute_flag[0] != 0)
            {
              flags=ParseGeometry(argument_list[0].string_reference,
                &geometry_info);
              if ((flags & SigmaValue) == 0)
                geometry_info.sigma=1.0;
            }
          if (attribute_flag[1] != 0)
            geometry_info.rho=argument_list[1].real_reference;
          if (attribute_flag[2] != 0)
            geometry_info.sigma=argument_list[2].real_reference;
          method=UndefinedInterpolatePixel;
          if (attribute_flag[3] != 0)
            method=(PixelInterpolateMethod) argument_list[3].integer_reference;
          image=WaveImage(image,geometry_info.rho,geometry_info.sigma,
            method,exception);
          break;
        }
        case 61:  /* Separate */
        {
          if (attribute_flag[0] != 0)
            channel=(ChannelType) argument_list[0].integer_reference;
          image=SeparateImage(image,channel,exception);
          break;
        }
        case 63:  /* Stereo */
        {
          if (attribute_flag[0] == 0)
            {
              ThrowPerlException(exception,OptionError,"StereoImageRequired",
                PackageName);
              goto PerlException;
            }
          if (attribute_flag[1] != 0)
            geometry.x=argument_list[1].integer_reference;
          if (attribute_flag[2] != 0)
            geometry.y=argument_list[2].integer_reference;
          image=StereoAnaglyphImage(image,argument_list[0].image_reference,
            geometry.x,geometry.y,exception);
          break;
        }
        case 64:  /* Stegano */
        {
          if (attribute_flag[0] == 0)
            {
              ThrowPerlException(exception,OptionError,"SteganoImageRequired",
                PackageName);
              goto PerlException;
            }
          if (attribute_flag[1] == 0)
            argument_list[1].integer_reference=0;
          image->offset=argument_list[1].integer_reference;
          image=SteganoImage(image,argument_list[0].image_reference,exception);
          break;
        }
        case 65:  /* Deconstruct */
        {
          image=CompareImagesLayers(image,CompareAnyLayer,exception);
          break;
        }
        case 66:  /* GaussianBlur */
        {
          if (attribute_flag[0] != 0)
            {
              flags=ParseGeometry(argument_list[0].string_reference,
                &geometry_info);
              if ((flags & SigmaValue) == 0)
                geometry_info.sigma=1.0;
            }
          if (attribute_flag[1] != 0)
            geometry_info.rho=argument_list[1].real_reference;
          if (attribute_flag[2] != 0)
            geometry_info.sigma=argument_list[2].real_reference;
          if (attribute_flag[3] != 0)
            channel=(ChannelType) argument_list[3].integer_reference;
          channel_mask=SetImageChannelMask(image,channel);
          image=GaussianBlurImage(image,geometry_info.rho,geometry_info.sigma,
            exception);
          if (image != (Image *) NULL)
            (void) SetImageChannelMask(image,channel_mask);
          break;
        }
        case 67:  /* Convolve */
        {
          KernelInfo
            *kernel;

          kernel=(KernelInfo *) NULL;
          if ((attribute_flag[0] == 0) && (attribute_flag[3] == 0))
            break;
          if (attribute_flag[0] != 0)
            {
              AV
                *av;

              size_t
                order;

              kernel=AcquireKernelInfo((const char *) NULL,exception);
              if (kernel == (KernelInfo *) NULL)
                break;
              av=(AV *) argument_list[0].array_reference;
              order=(size_t) sqrt(av_len(av)+1);
              kernel->width=order;
              kernel->height=order;
              kernel->values=(MagickRealType *) AcquireAlignedMemory(order,
                order*sizeof(*kernel->values));
              if (kernel->values == (MagickRealType *) NULL)
                {
                  kernel=DestroyKernelInfo(kernel);
                  ThrowPerlException(exception,ResourceLimitFatalError,
                    "MemoryAllocationFailed",PackageName);
                  goto PerlException;
                }
              for (j=0; (j < (ssize_t) (order*order)) && (j < (av_len(av)+1)); j++)
                kernel->values[j]=(MagickRealType) SvNV(*(av_fetch(av,j,0)));
              for ( ; j < (ssize_t) (order*order); j++)
                kernel->values[j]=0.0;
            }
          if (attribute_flag[1] != 0)
            channel=(ChannelType) argument_list[1].integer_reference;
          if (attribute_flag[2] != 0)
            SetImageArtifact(image,"convolve:bias",
              argument_list[2].string_reference);
          if (attribute_flag[3] != 0)
            {
              kernel=AcquireKernelInfo(argument_list[3].string_reference,
                exception);
              if (kernel == (KernelInfo *) NULL)
                break;
            }
          channel_mask=SetImageChannelMask(image,channel);
          image=ConvolveImage(image,kernel,exception);
          if (image != (Image *) NULL)
            (void) SetImageChannelMask(image,channel_mask);
          kernel=DestroyKernelInfo(kernel);
          break;
        }
        case 68:  /* Profile */
        {
          const char
            *name;

          Image
            *profile_image;

          ImageInfo
            *profile_info;

          StringInfo
            *profile;

          name="*";
          if (attribute_flag[0] != 0)
            name=argument_list[0].string_reference;
          if (attribute_flag[2] != 0)
            image->rendering_intent=(RenderingIntent)
              argument_list[2].integer_reference;
          if (attribute_flag[3] != 0)
            image->black_point_compensation=
              argument_list[3].integer_reference != 0 ? MagickTrue : MagickFalse;
          if (attribute_flag[1] != 0)
            {
              if (argument_list[1].length == 0)
                {
                  /*
                    Remove a profile from the image.
                  */
                  (void) ProfileImage(image,name,(const unsigned char *) NULL,0,
                    exception);
                  break;
                }
              /*
                Associate user supplied profile with the image.
              */
              profile=AcquireStringInfo(argument_list[1].length);
              SetStringInfoDatum(profile,(const unsigned char *)
                argument_list[1].string_reference);
              (void) ProfileImage(image,name,GetStringInfoDatum(profile),
                (size_t) GetStringInfoLength(profile),exception);
              profile=DestroyStringInfo(profile);
              break;
            }
          /*
            Associate a profile with the image.
          */
          profile_info=CloneImageInfo(info ? info->image_info :
            (ImageInfo *) NULL);
          profile_image=ReadImages(profile_info,name,exception);
          if (profile_image == (Image *) NULL)
            break;
          ResetImageProfileIterator(profile_image);
          name=GetNextImageProfile(profile_image);
          while (name != (const char *) NULL)
          {
            const StringInfo
              *profile;

            profile=GetImageProfile(profile_image,name);
            if (profile != (const StringInfo *) NULL)
              (void) ProfileImage(image,name,GetStringInfoDatum(profile),
                (size_t) GetStringInfoLength(profile),exception);
            name=GetNextImageProfile(profile_image);
          }
          profile_image=DestroyImage(profile_image);
          profile_info=DestroyImageInfo(profile_info);
          break;
        }
        case 69:  /* UnsharpMask */
        {
          if (attribute_flag[0] != 0)
            {
              flags=ParseGeometry(argument_list[0].string_reference,
                &geometry_info);
              if ((flags & SigmaValue) == 0)
                geometry_info.sigma=1.0;
              if ((flags & XiValue) == 0)
                geometry_info.xi=1.0;
              if ((flags & PsiValue) == 0)
                geometry_info.psi=0.5;
            }
          if (attribute_flag[1] != 0)
            geometry_info.rho=argument_list[1].real_reference;
          if (attribute_flag[2] != 0)
            geometry_info.sigma=argument_list[2].real_reference;
          if (attribute_flag[3] != 0)
            geometry_info.xi=argument_list[3].real_reference;
          if (attribute_flag[4] != 0)
            geometry_info.psi=argument_list[4].real_reference;
          if (attribute_flag[5] != 0)
            channel=(ChannelType) argument_list[5].integer_reference;
          channel_mask=SetImageChannelMask(image,channel);
          image=UnsharpMaskImage(image,geometry_info.rho,geometry_info.sigma,
            geometry_info.xi,geometry_info.psi,exception);
          if (image != (Image *) NULL)
            (void) SetImageChannelMask(image,channel_mask);
          break;
        }
        case 70:  /* MotionBlur */
        {
          if (attribute_flag[0] != 0)
            {
              flags=ParseGeometry(argument_list[0].string_reference,
                &geometry_info);
              if ((flags & SigmaValue) == 0)
                geometry_info.sigma=1.0;
              if ((flags & XiValue) == 0)
                geometry_info.xi=1.0;
            }
          if (attribute_flag[1] != 0)
            geometry_info.rho=argument_list[1].real_reference;
          if (attribute_flag[2] != 0)
            geometry_info.sigma=argument_list[2].real_reference;
          if (attribute_flag[3] != 0)
            geometry_info.xi=argument_list[3].real_reference;
          if (attribute_flag[4] != 0)
            channel=(ChannelType) argument_list[4].integer_reference;
          channel_mask=SetImageChannelMask(image,channel);
          image=MotionBlurImage(image,geometry_info.rho,geometry_info.sigma,
            geometry_info.xi,exception);
          if (image != (Image *) NULL)
            (void) SetImageChannelMask(image,channel_mask);
          break;
        }
        case 71:  /* OrderedDither */
        {
          if (attribute_flag[0] == 0)
            argument_list[0].string_reference="o8x8";
          if (attribute_flag[1] != 0)
            channel=(ChannelType) argument_list[1].integer_reference;
          channel_mask=SetImageChannelMask(image,channel);
          (void) OrderedDitherImage(image,argument_list[0].string_reference,
            exception);
          (void) SetImageChannelMask(image,channel_mask);
          break;
        }
        case 72:  /* Shave */
        {
          if (attribute_flag[0] != 0)
            flags=ParsePageGeometry(image,argument_list[0].string_reference,
              &geometry,exception);
          if (attribute_flag[1] != 0)
            geometry.width=(size_t) argument_list[1].integer_reference;
          if (attribute_flag[2] != 0)
            geometry.height=(size_t) argument_list[2].integer_reference;
          image=ShaveImage(image,&geometry,exception);
          break;
        }
        case 73:  /* Level */
        {
          double
            black_point,
            gamma,
            white_point;

          black_point=0.0;
          white_point=(double) image->columns*image->rows;
          gamma=1.0;
          if (attribute_flag[0] != 0)
            {
              flags=ParseGeometry(argument_list[0].string_reference,
                &geometry_info);
              black_point=geometry_info.rho;
              if ((flags & SigmaValue) != 0)
                white_point=geometry_info.sigma;
              if ((flags & XiValue) != 0)
                gamma=geometry_info.xi;
              if ((flags & PercentValue) != 0)
                {
                  black_point*=(double) (QuantumRange/100.0);
                  white_point*=(double) (QuantumRange/100.0);
                }
              if ((flags & SigmaValue) == 0)
                white_point=(double) QuantumRange-black_point;
            }
          if (attribute_flag[1] != 0)
            black_point=argument_list[1].real_reference;
          if (attribute_flag[2] != 0)
            white_point=argument_list[2].real_reference;
          if (attribute_flag[3] != 0)
            gamma=argument_list[3].real_reference;
          if (attribute_flag[4] != 0)
            channel=(ChannelType) argument_list[4].integer_reference;
          if (attribute_flag[5] != 0)
            {
              argument_list[0].real_reference=argument_list[5].real_reference;
              attribute_flag[0]=attribute_flag[5];
            }
          channel_mask=SetImageChannelMask(image,channel);
          (void) LevelImage(image,black_point,white_point,gamma,exception);
          (void) SetImageChannelMask(image,channel_mask);
          break;
        }
        case 74:  /* Clip */
        {
          if (attribute_flag[0] == 0)
            argument_list[0].string_reference="#1";
          if (attribute_flag[1] == 0)
            argument_list[1].integer_reference=MagickTrue;
          (void) ClipImagePath(image,argument_list[0].string_reference,
            argument_list[1].integer_reference != 0 ? MagickTrue : MagickFalse,
            exception);
          break;
        }
        case 75:  /* AffineTransform */
        {
          DrawInfo
            *draw_info;

          draw_info=CloneDrawInfo(info ? info->image_info : (ImageInfo *) NULL,
            (DrawInfo *) NULL);
          if (attribute_flag[0] != 0)
            {
              AV
                *av;

              av=(AV *) argument_list[0].array_reference;
              if ((av_len(av) != 3) && (av_len(av) != 5))
                {
                  ThrowPerlException(exception,OptionError,
                    "affine matrix must have 4 or 6 elements",PackageName);
                  goto PerlException;
                }
              draw_info->affine.sx=(double) SvNV(*(av_fetch(av,0,0)));
              draw_info->affine.rx=(double) SvNV(*(av_fetch(av,1,0)));
              draw_info->affine.ry=(double) SvNV(*(av_fetch(av,2,0)));
              draw_info->affine.sy=(double) SvNV(*(av_fetch(av,3,0)));
              if (fabs(draw_info->affine.sx*draw_info->affine.sy-
                  draw_info->affine.rx*draw_info->affine.ry) < MagickEpsilon)
                {
                  ThrowPerlException(exception,OptionError,
                    "affine matrix is singular",PackageName);
                   goto PerlException;
                }
              if (av_len(av) == 5)
                {
                  draw_info->affine.tx=(double) SvNV(*(av_fetch(av,4,0)));
                  draw_info->affine.ty=(double) SvNV(*(av_fetch(av,5,0)));
                }
            }
          for (j=1; j < 6; j++)
          {
            if (attribute_flag[j] == 0)
              continue;
            value=argument_list[j].string_reference;
            angle=argument_list[j].real_reference;
            current=draw_info->affine;
            GetAffineMatrix(&affine);
            switch (j)
            {
              case 1:
              {
                /*
                  Translate.
                */
                flags=ParseGeometry(value,&geometry_info);
                affine.tx=geometry_info.xi;
                affine.ty=geometry_info.psi;
                if ((flags & PsiValue) == 0)
                  affine.ty=affine.tx;
                break;
              }
              case 2:
              {
                /*
                  Scale.
                */
                flags=ParseGeometry(value,&geometry_info);
                affine.sx=geometry_info.rho;
                affine.sy=geometry_info.sigma;
                if ((flags & SigmaValue) == 0)
                  affine.sy=affine.sx;
                break;
              }
              case 3:
              {
                /*
                  Rotate.
                */
                if (angle == 0.0)
                  break;
                affine.sx=cos(DegreesToRadians(fmod(angle,360.0)));
                affine.rx=sin(DegreesToRadians(fmod(angle,360.0)));
                affine.ry=(-sin(DegreesToRadians(fmod(angle,360.0))));
                affine.sy=cos(DegreesToRadians(fmod(angle,360.0)));
                break;
              }
              case 4:
              {
                /*
                  SkewX.
                */
                affine.ry=tan(DegreesToRadians(fmod(angle,360.0)));
                break;
              }
              case 5:
              {
                /*
                  SkewY.
                */
                affine.rx=tan(DegreesToRadians(fmod(angle,360.0)));
                break;
              }
            }
            draw_info->affine.sx=current.sx*affine.sx+current.ry*affine.rx;
            draw_info->affine.rx=current.rx*affine.sx+current.sy*affine.rx;
            draw_info->affine.ry=current.sx*affine.ry+current.ry*affine.sy;
            draw_info->affine.sy=current.rx*affine.ry+current.sy*affine.sy;
            draw_info->affine.tx=
              current.sx*affine.tx+current.ry*affine.ty+current.tx;
            draw_info->affine.ty=
              current.rx*affine.tx+current.sy*affine.ty+current.ty;
          }
          if (attribute_flag[6] != 0)
            image->interpolate=(PixelInterpolateMethod)
              argument_list[6].integer_reference;
          if (attribute_flag[7] != 0)
            QueryColorCompliance(argument_list[7].string_reference,
              AllCompliance,&image->background_color,exception);
          image=AffineTransformImage(image,&draw_info->affine,exception);
          draw_info=DestroyDrawInfo(draw_info);
          break;
        }
        case 76:  /* Difference */
        {
          if (attribute_flag[0] == 0)
            {
              ThrowPerlException(exception,OptionError,
                "ReferenceImageRequired",PackageName);
              goto PerlException;
            }
          if (attribute_flag[1] != 0)
            image->fuzz=StringToDoubleInterval(
              argument_list[1].string_reference,(double) QuantumRange+1.0);
          (void) SetImageColorMetric(image,argument_list[0].image_reference,
            exception);
          break;
        }
        case 77:  /* AdaptiveThreshold */
        {
          if (attribute_flag[0] != 0)
            {
              flags=ParseGeometry(argument_list[0].string_reference,
                &geometry_info);
              if ((flags & PercentValue) != 0)
                geometry_info.xi=QuantumRange*geometry_info.xi/100.0;
            }
          if (attribute_flag[1] != 0)
            geometry_info.rho=argument_list[1].integer_reference;
          if (attribute_flag[2] != 0)
            geometry_info.sigma=argument_list[2].integer_reference;
          if (attribute_flag[3] != 0)
            geometry_info.xi=argument_list[3].integer_reference;;
          image=AdaptiveThresholdImage(image,(size_t) geometry_info.rho,
            (size_t) geometry_info.sigma,(double) geometry_info.xi,exception);
          break;
        }
        case 78:  /* Resample */
        {
          size_t
            height,
            width;

          if (attribute_flag[0] != 0)
            {
              flags=ParseGeometry(argument_list[0].string_reference,
                &geometry_info);
              if ((flags & SigmaValue) == 0)
                geometry_info.sigma=geometry_info.rho;
            }
          if (attribute_flag[1] != 0)
            geometry_info.rho=argument_list[1].real_reference;
          if (attribute_flag[2] != 0)
            geometry_info.sigma=argument_list[2].real_reference;
          if (attribute_flag[3] == 0)
            argument_list[3].integer_reference=(ssize_t) UndefinedFilter;
          if (attribute_flag[4] == 0)
            SetImageArtifact(image,"filter:support",
              argument_list[4].string_reference);
          width=(size_t) (geometry_info.rho*image->columns/
            (image->resolution.x == 0.0 ? 72.0 : image->resolution.x)+0.5);
          height=(size_t) (geometry_info.sigma*image->rows/
            (image->resolution.y == 0.0 ? 72.0 : image->resolution.y)+0.5);
          image=ResizeImage(image,width,height,(FilterType)
            argument_list[3].integer_reference,exception);
          if (image != (Image *) NULL)
            {
              image->resolution.x=geometry_info.rho;
              image->resolution.y=geometry_info.sigma;
            }
          break;
        }
        case 79:  /* Describe */
        {
          if (attribute_flag[0] == 0)
            argument_list[0].file_reference=(FILE *) NULL;
          (void) IdentifyImage(image,argument_list[0].file_reference,
            MagickTrue,exception);
          break;
        }
        case 80:  /* BlackThreshold */
        {
          if (attribute_flag[0] == 0)
            argument_list[0].string_reference="50%";
          if (attribute_flag[2] != 0)
            channel=(ChannelType) argument_list[2].integer_reference;
          channel_mask=SetImageChannelMask(image,channel);
          (void) BlackThresholdImage(image,argument_list[0].string_reference,
            exception);
          (void) SetImageChannelMask(image,channel_mask);
          break;
        }
        case 81:  /* WhiteThreshold */
        {
          if (attribute_flag[0] == 0)
            argument_list[0].string_reference="50%";
          if (attribute_flag[2] != 0)
            channel=(ChannelType) argument_list[2].integer_reference;
          channel_mask=SetImageChannelMask(image,channel);
          WhiteThresholdImage(image,argument_list[0].string_reference,
            exception);
          (void) SetImageChannelMask(image,channel_mask);
          break;
        }
        case 82:  /* RotationalBlur */
        {
          if (attribute_flag[0] != 0)
            {
              flags=ParseGeometry(argument_list[0].string_reference,
                &geometry_info);
            }
          if (attribute_flag[1] != 0)
            geometry_info.rho=argument_list[1].real_reference;
          if (attribute_flag[2] != 0)
            channel=(ChannelType) argument_list[2].integer_reference;
          channel_mask=SetImageChannelMask(image,channel);
          image=RotationalBlurImage(image,geometry_info.rho,exception);
          if (image != (Image *) NULL)
            (void) SetImageChannelMask(image,channel_mask);
          break;
        }
        case 83:  /* Thumbnail */
        {
          if (attribute_flag[0] != 0)
            flags=ParseRegionGeometry(image,argument_list[0].string_reference,
              &geometry,exception);
          if (attribute_flag[1] != 0)
            geometry.width=(size_t) argument_list[1].integer_reference;
          if (attribute_flag[2] != 0)
            geometry.height=(size_t) argument_list[2].integer_reference;
          image=ThumbnailImage(image,geometry.width,geometry.height,exception);
          break;
        }
        case 84:  /* Strip */
        {
          (void) StripImage(image,exception);
          break;
        }
        case 85:  /* Tint */
        {
          PixelInfo
            tint;

          GetPixelInfo(image,&tint);
          if (attribute_flag[0] != 0)
            (void) QueryColorCompliance(argument_list[0].string_reference,
              AllCompliance,&tint,exception);
          if (attribute_flag[1] == 0)
            argument_list[1].string_reference="100";
          image=TintImage(image,argument_list[1].string_reference,&tint,
            exception);
          break;
        }
        case 86:  /* Channel */
        {
          if (attribute_flag[0] != 0)
            channel=(ChannelType) argument_list[0].integer_reference;
          image=SeparateImage(image,channel,exception);
          break;
        }
        case 87:  /* Splice */
        {
          if (attribute_flag[7] != 0)
            image->gravity=(GravityType) argument_list[7].integer_reference;
          if (attribute_flag[0] != 0)
            flags=ParseGravityGeometry(image,argument_list[0].string_reference,
              &geometry,exception);
          if (attribute_flag[1] != 0)
            geometry.width=(size_t) argument_list[1].integer_reference;
          if (attribute_flag[2] != 0)
            geometry.height=(size_t) argument_list[2].integer_reference;
          if (attribute_flag[3] != 0)
            geometry.x=argument_list[3].integer_reference;
          if (attribute_flag[4] != 0)
            geometry.y=argument_list[4].integer_reference;
          if (attribute_flag[5] != 0)
            image->fuzz=StringToDoubleInterval(
              argument_list[5].string_reference,(double) QuantumRange+1.0);
          if (attribute_flag[6] != 0)
            (void) QueryColorCompliance(argument_list[6].string_reference,
              AllCompliance,&image->background_color,exception);
          image=SpliceImage(image,&geometry,exception);
          break;
        }
        case 88:  /* Posterize */
        {
          if (attribute_flag[0] == 0)
            argument_list[0].integer_reference=3;
          if (attribute_flag[1] == 0)
            argument_list[1].integer_reference=0;
          (void) PosterizeImage(image,(size_t)
            argument_list[0].integer_reference,
            argument_list[1].integer_reference ? RiemersmaDitherMethod :
            NoDitherMethod,exception);
          break;
        }
        case 89:  /* Shadow */
        {
          if (attribute_flag[0] != 0)
            {
              flags=ParseGeometry(argument_list[0].string_reference,
                &geometry_info);
              if ((flags & SigmaValue) == 0)
                geometry_info.sigma=1.0;
              if ((flags & XiValue) == 0)
                geometry_info.xi=4.0;
              if ((flags & PsiValue) == 0)
                geometry_info.psi=4.0;
            }
          if (attribute_flag[1] != 0)
            geometry_info.rho=argument_list[1].real_reference;
          if (attribute_flag[2] != 0)
            geometry_info.sigma=argument_list[2].real_reference;
          if (attribute_flag[3] != 0)
            geometry_info.xi=argument_list[3].integer_reference;
          if (attribute_flag[4] != 0)
            geometry_info.psi=argument_list[4].integer_reference;
          image=ShadowImage(image,geometry_info.rho,geometry_info.sigma,
            (ssize_t) ceil(geometry_info.xi-0.5),(ssize_t)
            ceil(geometry_info.psi-0.5),exception);
          break;
        }
        case 90:  /* Identify */
        {
          if (attribute_flag[0] == 0)
            argument_list[0].file_reference=(FILE *) NULL;
          if (attribute_flag[1] != 0)
            (void) SetImageArtifact(image,"identify:features",
              argument_list[1].string_reference);
          if ((attribute_flag[2] != 0) &&
              (argument_list[2].integer_reference != 0))
            (void) SetImageArtifact(image,"identify:moments","true");
          if ((attribute_flag[3] != 0) &&
              (argument_list[3].integer_reference != 0))
            (void) SetImageArtifact(image,"identify:unique","true");
          (void) IdentifyImage(image,argument_list[0].file_reference,
            MagickTrue,exception);
          break;
        }
        case 91:  /* SepiaTone */
        {
          if (attribute_flag[0] == 0)
            argument_list[0].real_reference=80.0*QuantumRange/100.0;
          image=SepiaToneImage(image,argument_list[0].real_reference,
            exception);
          break;
        }
        case 92:  /* SigmoidalContrast */
        {
          MagickBooleanType
            sharpen;

          if (attribute_flag[0] != 0)
            {
              flags=ParseGeometry(argument_list[0].string_reference,
                &geometry_info);
              if ((flags & SigmaValue) == 0)
                geometry_info.sigma=QuantumRange/2.0;
              if ((flags & PercentValue) != 0)
                geometry_info.sigma=QuantumRange*geometry_info.sigma/100.0;
            }
          if (attribute_flag[1] != 0)
            geometry_info.rho=argument_list[1].real_reference;
          if (attribute_flag[2] != 0)
            geometry_info.sigma=argument_list[2].real_reference;
          if (attribute_flag[3] != 0)
            channel=(ChannelType) argument_list[3].integer_reference;
          sharpen=MagickTrue;
          if (attribute_flag[4] != 0)
            sharpen=argument_list[4].integer_reference != 0 ? MagickTrue :
              MagickFalse;
          channel_mask=SetImageChannelMask(image,channel);
          (void) SigmoidalContrastImage(image,sharpen,geometry_info.rho,
            geometry_info.sigma,exception);
          (void) SetImageChannelMask(image,channel_mask);
          break;
        }
        case 93:  /* Extent */
        {
          if (attribute_flag[7] != 0)
            image->gravity=(GravityType) argument_list[7].integer_reference;
          if (attribute_flag[0] != 0)
            {
              MagickStatusType
                flags;

              flags=ParseGravityGeometry(image,
                argument_list[0].string_reference,&geometry,exception);
              (void) flags;
              if (geometry.width == 0)
                geometry.width=image->columns;
              if (geometry.height == 0)
                geometry.height=image->rows;
            }
          if (attribute_flag[1] != 0)
            geometry.width=(size_t) argument_list[1].integer_reference;
          if (attribute_flag[2] != 0)
            geometry.height=(size_t) argument_list[2].integer_reference;
          if (attribute_flag[3] != 0)
            geometry.x=argument_list[3].integer_reference;
          if (attribute_flag[4] != 0)
            geometry.y=argument_list[4].integer_reference;
          if (attribute_flag[5] != 0)
            image->fuzz=StringToDoubleInterval(
              argument_list[5].string_reference,(double) QuantumRange+1.0);
          if (attribute_flag[6] != 0)
            (void) QueryColorCompliance(argument_list[6].string_reference,
              AllCompliance,&image->background_color,exception);
          image=ExtentImage(image,&geometry,exception);
          break;
        }
        case 94:  /* Vignette */
        {
          if (attribute_flag[0] != 0)
            {
              flags=ParseGeometry(argument_list[0].string_reference,
                &geometry_info);
              if ((flags & SigmaValue) == 0)
                geometry_info.sigma=1.0;
              if ((flags & XiValue) == 0)
                geometry_info.xi=0.1*image->columns;
              if ((flags & PsiValue) == 0)
                geometry_info.psi=0.1*image->rows;
            }
          if (attribute_flag[1] != 0)
            geometry_info.rho=argument_list[1].real_reference;
          if (attribute_flag[2] != 0)
            geometry_info.sigma=argument_list[2].real_reference;
          if (attribute_flag[3] != 0)
            geometry_info.xi=argument_list[3].integer_reference;
          if (attribute_flag[4] != 0)
            geometry_info.psi=argument_list[4].integer_reference;
          if (attribute_flag[5] != 0)
            (void) QueryColorCompliance(argument_list[5].string_reference,
              AllCompliance,&image->background_color,exception);
          image=VignetteImage(image,geometry_info.rho,geometry_info.sigma,
            (ssize_t) ceil(geometry_info.xi-0.5),(ssize_t)
            ceil(geometry_info.psi-0.5),exception);
          break;
        }
        case 95:  /* ContrastStretch */
        {
          double
            black_point,
            white_point;

          black_point=0.0;
          white_point=(double) image->columns*image->rows;
          if (attribute_flag[0] != 0)
            {
              flags=ParseGeometry(argument_list[0].string_reference,
                &geometry_info);
              black_point=geometry_info.rho;
              white_point=(flags & SigmaValue) != 0 ? geometry_info.sigma :
                black_point;
              if ((flags & PercentValue) != 0)
                {
                  black_point*=(double) image->columns*image->rows/100.0;
                  white_point*=(double) image->columns*image->rows/100.0;
                }
              white_point=(double) image->columns*image->rows-
                white_point;
            }
          if (attribute_flag[1] != 0)
            black_point=argument_list[1].real_reference;
          if (attribute_flag[2] != 0)
            white_point=argument_list[2].real_reference;
          if (attribute_flag[4] != 0)
            channel=(ChannelType) argument_list[4].integer_reference;
          channel_mask=SetImageChannelMask(image,channel);
          (void) ContrastStretchImage(image,black_point,white_point,exception);
          (void) SetImageChannelMask(image,channel_mask);
          break;
        }
        case 96:  /* Sans0 */
        {
          break;
        }
        case 97:  /* Sans1 */
        {
          break;
        }
        case 98:  /* AdaptiveSharpen */
        {
          if (attribute_flag[0] != 0)
            {
              flags=ParseGeometry(argument_list[0].string_reference,
                &geometry_info);
              if ((flags & SigmaValue) == 0)
                geometry_info.sigma=1.0;
              if ((flags & XiValue) == 0)
                geometry_info.xi=0.0;
            }
          if (attribute_flag[1] != 0)
            geometry_info.rho=argument_list[1].real_reference;
          if (attribute_flag[2] != 0)
            geometry_info.sigma=argument_list[2].real_reference;
          if (attribute_flag[3] != 0)
            geometry_info.xi=argument_list[3].real_reference;
          if (attribute_flag[4] != 0)
            channel=(ChannelType) argument_list[4].integer_reference;
          channel_mask=SetImageChannelMask(image,channel);
          image=AdaptiveSharpenImage(image,geometry_info.rho,
            geometry_info.sigma,exception);
          if (image != (Image *) NULL)
            (void) SetImageChannelMask(image,channel_mask);
          break;
        }
        case 99:  /* Transpose */
        {
          image=TransposeImage(image,exception);
          break;
        }
        case 100:  /* Transverse */
        {
          image=TransverseImage(image,exception);
          break;
        }
        case 101:  /* AutoOrient */
        {
          image=AutoOrientImage(image,image->orientation,exception);
          break;
        }
        case 102:  /* AdaptiveBlur */
        {
          if (attribute_flag[0] != 0)
            {
              flags=ParseGeometry(argument_list[0].string_reference,
                &geometry_info);
              if ((flags & SigmaValue) == 0)
                geometry_info.sigma=1.0;
              if ((flags & XiValue) == 0)
                geometry_info.xi=0.0;
            }
          if (attribute_flag[1] != 0)
            geometry_info.rho=argument_list[1].real_reference;
          if (attribute_flag[2] != 0)
            geometry_info.sigma=argument_list[2].real_reference;
          if (attribute_flag[3] != 0)
            channel=(ChannelType) argument_list[3].integer_reference;
          channel_mask=SetImageChannelMask(image,channel);
          image=AdaptiveBlurImage(image,geometry_info.rho,geometry_info.sigma,
            exception);
          if (image != (Image *) NULL)
            (void) SetImageChannelMask(image,channel_mask);
          break;
        }
        case 103:  /* Sketch */
        {
          if (attribute_flag[0] != 0)
            {
              flags=ParseGeometry(argument_list[0].string_reference,
                &geometry_info);
              if ((flags & SigmaValue) == 0)
                geometry_info.sigma=1.0;
              if ((flags & XiValue) == 0)
                geometry_info.xi=1.0;
            }
          if (attribute_flag[1] != 0)
            geometry_info.rho=argument_list[1].real_reference;
          if (attribute_flag[2] != 0)
            geometry_info.sigma=argument_list[2].real_reference;
          if (attribute_flag[3] != 0)
            geometry_info.xi=argument_list[3].real_reference;
          image=SketchImage(image,geometry_info.rho,geometry_info.sigma,
            geometry_info.xi,exception);
          break;
        }
        case 104:  /* UniqueColors */
        {
          image=UniqueImageColors(image,exception);
          break;
        }
        case 105:  /* AdaptiveResize */
        {
          if (attribute_flag[0] != 0)
            flags=ParseRegionGeometry(image,argument_list[0].string_reference,
              &geometry,exception);
          if (attribute_flag[1] != 0)
            geometry.width=(size_t) argument_list[1].integer_reference;
          if (attribute_flag[2] != 0)
            geometry.height=(size_t) argument_list[2].integer_reference;
          if (attribute_flag[3] != 0)
            image->filter=(FilterType) argument_list[4].integer_reference;
          if (attribute_flag[4] != 0)
            SetImageArtifact(image,"filter:support",
              argument_list[4].string_reference);
          image=AdaptiveResizeImage(image,geometry.width,geometry.height,
            exception);
          break;
        }
        case 106:  /* ClipMask */
        {
          Image
            *mask_image;

          if (attribute_flag[0] == 0)
            {
              ThrowPerlException(exception,OptionError,"MaskImageRequired",
                PackageName);
              goto PerlException;
            }
          mask_image=CloneImage(argument_list[0].image_reference,0,0,MagickTrue,
            exception);
          (void) SetImageMask(image,ReadPixelMask,mask_image,exception);
          mask_image=DestroyImage(mask_image);
          break;
        }
        case 107:  /* LinearStretch */
        {
           double
             black_point,
             white_point;

           black_point=0.0;
           white_point=(double) image->columns*image->rows;
           if (attribute_flag[0] != 0)
             {
               flags=ParseGeometry(argument_list[0].string_reference,
                 &geometry_info);
               if ((flags & SigmaValue) != 0)
                  white_point=geometry_info.sigma;
               if ((flags & PercentValue) != 0)
                 {
                   black_point*=(double) image->columns*image->rows/100.0;
                   white_point*=(double) image->columns*image->rows/100.0;
                 }
               if ((flags & SigmaValue) == 0)
                 white_point=(double) image->columns*image->rows-black_point;
             }
          if (attribute_flag[1] != 0)
            black_point=argument_list[1].real_reference;
          if (attribute_flag[2] != 0)
            white_point=argument_list[2].real_reference;
          (void) LinearStretchImage(image,black_point,white_point,exception);
          break;
        }
        case 108:  /* ColorMatrix */
        {
          AV
            *av;

          double
            *color_matrix;

          KernelInfo
            *kernel_info;

          size_t
            order;

          if (attribute_flag[0] == 0)
            break;
          av=(AV *) argument_list[0].array_reference;
          order=(size_t) sqrt(av_len(av)+1);
          color_matrix=(double *) AcquireQuantumMemory(order,order*
            sizeof(*color_matrix));
          if (color_matrix == (double *) NULL)
            {
              ThrowPerlException(exception,ResourceLimitFatalError,
                "MemoryAllocationFailed",PackageName);
              goto PerlException;
           }
          for (j=0; (j < (ssize_t) (order*order)) && (j < (av_len(av)+1)); j++)
            color_matrix[j]=(double) SvNV(*(av_fetch(av,j,0)));
          for ( ; j < (ssize_t) (order*order); j++)
            color_matrix[j]=0.0;
          kernel_info=AcquireKernelInfo((const char *) NULL,exception);
          if (kernel_info == (KernelInfo *) NULL)
            break;
          kernel_info->width=order;
          kernel_info->height=order;
          kernel_info->values=(MagickRealType *) AcquireAlignedMemory(order,
            order*sizeof(*kernel_info->values));
          if (kernel_info->values != (MagickRealType *) NULL)
            {
              for (i=0; i < (ssize_t) (order*order); i++)
                kernel_info->values[i]=(MagickRealType) color_matrix[i];
              image=ColorMatrixImage(image,kernel_info,exception);
            }
          kernel_info=DestroyKernelInfo(kernel_info);
          color_matrix=(double *) RelinquishMagickMemory(color_matrix);
          break;
        }
        case 109:  /* Mask */
        {
          Image
            *mask_image;

          if (attribute_flag[0] == 0)
            {
              ThrowPerlException(exception,OptionError,"MaskImageRequired",
                PackageName);
              goto PerlException;
            }
          mask_image=CloneImage(argument_list[0].image_reference,0,0,
            MagickTrue,exception);
          (void) SetImageMask(image,ReadPixelMask,mask_image,exception);
          mask_image=DestroyImage(mask_image);
          break;
        }
        case 110:  /* Polaroid */
        {
          char
            *caption;

          DrawInfo
            *draw_info;

          double
            angle;

          PixelInterpolateMethod
            method;

          draw_info=CloneDrawInfo(info ? info->image_info : (ImageInfo *) NULL,
            (DrawInfo *) NULL);
          caption=(char *) NULL;
          if (attribute_flag[0] != 0)
            caption=InterpretImageProperties(info ? info->image_info :
              (ImageInfo *) NULL,image,argument_list[0].string_reference,
              exception);
          angle=0.0;
          if (attribute_flag[1] != 0)
            angle=argument_list[1].real_reference;
          if (attribute_flag[2] != 0)
            (void) CloneString(&draw_info->font,
              argument_list[2].string_reference);
          if (attribute_flag[3] != 0)
            (void) QueryColorCompliance(argument_list[3].string_reference,
              AllCompliance,&draw_info->stroke,exception);
          if (attribute_flag[4] != 0)
            (void) QueryColorCompliance(argument_list[4].string_reference,
              AllCompliance,&draw_info->fill,exception);
          if (attribute_flag[5] != 0)
            draw_info->stroke_width=(size_t) argument_list[5].real_reference;
          if (attribute_flag[6] != 0)
            draw_info->pointsize=argument_list[6].real_reference;
          if (attribute_flag[7] != 0)
            draw_info->gravity=(GravityType) argument_list[7].integer_reference;
          if (attribute_flag[8] != 0)
            (void) QueryColorCompliance(argument_list[8].string_reference,
              AllCompliance,&image->background_color,exception);
          method=UndefinedInterpolatePixel;
          if (attribute_flag[9] != 0)
            method=(PixelInterpolateMethod) argument_list[9].integer_reference;
          image=PolaroidImage(image,draw_info,caption,angle,method,exception);
          draw_info=DestroyDrawInfo(draw_info);
          if (caption != (char *) NULL)
            caption=DestroyString(caption);
          break;
        }
        case 111:  /* FloodfillPaint */
        {
          DrawInfo
            *draw_info;

          MagickBooleanType
            invert;

          PixelInfo
            target;

          draw_info=CloneDrawInfo(info ? info->image_info :
            (ImageInfo *) NULL,(DrawInfo *) NULL);
          if (attribute_flag[0] != 0)
            flags=ParsePageGeometry(image,argument_list[0].string_reference,
              &geometry,exception);
          if (attribute_flag[1] != 0)
            geometry.x=argument_list[1].integer_reference;
          if (attribute_flag[2] != 0)
            geometry.y=argument_list[2].integer_reference;
          if (attribute_flag[3] != 0)
            (void) QueryColorCompliance(argument_list[3].string_reference,
              AllCompliance,&draw_info->fill,exception);
          (void) GetOneVirtualPixelInfo(image,UndefinedVirtualPixelMethod,
            geometry.x,geometry.y,&target,exception);
          if (attribute_flag[4] != 0)
            QueryColorCompliance(argument_list[4].string_reference,
              AllCompliance,&target,exception);
          if (attribute_flag[5] != 0)
            image->fuzz=StringToDoubleInterval(
              argument_list[5].string_reference,(double) QuantumRange+1.0);
          if (attribute_flag[6] != 0)
            channel=(ChannelType) argument_list[6].integer_reference;
          invert=MagickFalse;
          if (attribute_flag[7] != 0)
            invert=(MagickBooleanType) argument_list[7].integer_reference;
          channel_mask=SetImageChannelMask(image,channel);
          (void) FloodfillPaintImage(image,draw_info,&target,geometry.x,
            geometry.y,invert,exception);
          (void) SetImageChannelMask(image,channel_mask);
          draw_info=DestroyDrawInfo(draw_info);
          break;
        }
        case 112:  /* Distort */
        {
          AV
            *av;

          double
            *coordinates;

          DistortMethod
            method;

          size_t
            number_coordinates;

          VirtualPixelMethod
            virtual_pixel;

          if (attribute_flag[0] == 0)
            break;
          method=UndefinedDistortion;
          if (attribute_flag[1] != 0)
            method=(DistortMethod) argument_list[1].integer_reference;
          av=(AV *) argument_list[0].array_reference;
          number_coordinates=(size_t) av_len(av)+1;
          coordinates=(double *) AcquireQuantumMemory(number_coordinates,
            sizeof(*coordinates));
          if (coordinates == (double *) NULL)
            {
              ThrowPerlException(exception,ResourceLimitFatalError,
                "MemoryAllocationFailed",PackageName);
              goto PerlException;
            }
          for (j=0; j < (ssize_t) number_coordinates; j++)
            coordinates[j]=(double) SvNV(*(av_fetch(av,j,0)));
          virtual_pixel=UndefinedVirtualPixelMethod;
          if (attribute_flag[2] != 0)
            virtual_pixel=SetImageVirtualPixelMethod(image,(VirtualPixelMethod)
              argument_list[2].integer_reference,exception);
          image=DistortImage(image,method,number_coordinates,coordinates,
            argument_list[3].integer_reference != 0 ? MagickTrue : MagickFalse,
            exception);
          if ((attribute_flag[2] != 0) && (image != (Image *) NULL))
            virtual_pixel=SetImageVirtualPixelMethod(image,virtual_pixel,
              exception);
          coordinates=(double *) RelinquishMagickMemory(coordinates);
          break;
        }
        case 113:  /* Clut */
        {
          PixelInterpolateMethod
            method;

          if (attribute_flag[0] == 0)
            {
              ThrowPerlException(exception,OptionError,"ClutImageRequired",
                PackageName);
              goto PerlException;
            }
          method=UndefinedInterpolatePixel;
          if (attribute_flag[1] != 0)
            method=(PixelInterpolateMethod) argument_list[1].integer_reference;
          if (attribute_flag[2] != 0)
            channel=(ChannelType) argument_list[2].integer_reference;
          channel_mask=SetImageChannelMask(image,channel);
          (void) ClutImage(image,argument_list[0].image_reference,method,
            exception);
          (void) SetImageChannelMask(image,channel_mask);
          break;
        }
        case 114:  /* LiquidRescale */
        {
          if (attribute_flag[0] != 0)
            flags=ParseRegionGeometry(image,argument_list[0].string_reference,
              &geometry,exception);
          if (attribute_flag[1] != 0)
            geometry.width=(size_t) argument_list[1].integer_reference;
          if (attribute_flag[2] != 0)
            geometry.height=(size_t) argument_list[2].integer_reference;
          if (attribute_flag[3] == 0)
            argument_list[3].real_reference=1.0;
          if (attribute_flag[4] == 0)
            argument_list[4].real_reference=0.0;
          image=LiquidRescaleImage(image,geometry.width,geometry.height,
            argument_list[3].real_reference,argument_list[4].real_reference,
            exception);
          break;
        }
        case 115:  /* EncipherImage */
        {
          (void) EncipherImage(image,argument_list[0].string_reference,
            exception);
          break;
        }
        case 116:  /* DecipherImage */
        {
          (void) DecipherImage(image,argument_list[0].string_reference,
            exception);
          break;
        }
        case 117:  /* Deskew */
        {
          geometry_info.rho=QuantumRange/2.0;
          if (attribute_flag[0] != 0)
            flags=ParseGeometry(argument_list[0].string_reference,
              &geometry_info);
          if (attribute_flag[1] != 0)
            geometry_info.rho=StringToDoubleInterval(
              argument_list[1].string_reference,(double) QuantumRange+1.0);
          image=DeskewImage(image,geometry_info.rho,exception);
          break;
        }
        case 118:  /* Remap */
        {
          QuantizeInfo
            *quantize_info;

          if (attribute_flag[0] == 0)
            {
              ThrowPerlException(exception,OptionError,"RemapImageRequired",
                PackageName);
              goto PerlException;
            }
          quantize_info=AcquireQuantizeInfo(info->image_info);
          if (attribute_flag[1] != 0)
            quantize_info->dither_method=(DitherMethod)
              argument_list[1].integer_reference;
          (void) RemapImages(quantize_info,image,
            argument_list[0].image_reference,exception);
          quantize_info=DestroyQuantizeInfo(quantize_info);
          break;
        }
        case 119:  /* SparseColor */
        {
          AV
            *av;

          double
            *coordinates;

          SparseColorMethod
            method;

          size_t
            number_coordinates;

          VirtualPixelMethod
            virtual_pixel;

          if (attribute_flag[0] == 0)
            break;
          method=UndefinedColorInterpolate;
          if (attribute_flag[1] != 0)
            method=(SparseColorMethod) argument_list[1].integer_reference;
          av=(AV *) argument_list[0].array_reference;
          number_coordinates=(size_t) av_len(av)+1;
          coordinates=(double *) AcquireQuantumMemory(number_coordinates,
            sizeof(*coordinates));
          if (coordinates == (double *) NULL)
            {
              ThrowPerlException(exception,ResourceLimitFatalError,
                "MemoryAllocationFailed",PackageName);
              goto PerlException;
            }
          for (j=0; j < (ssize_t) number_coordinates; j++)
            coordinates[j]=(double) SvNV(*(av_fetch(av,j,0)));
          virtual_pixel=UndefinedVirtualPixelMethod;
          if (attribute_flag[2] != 0)
            virtual_pixel=SetImageVirtualPixelMethod(image,(VirtualPixelMethod)
              argument_list[2].integer_reference,exception);
          if (attribute_flag[3] != 0)
            channel=(ChannelType) argument_list[3].integer_reference;
          channel_mask=SetImageChannelMask(image,channel);
          image=SparseColorImage(image,method,number_coordinates,coordinates,
            exception);
          if (image != (Image *) NULL)
            (void) SetImageChannelMask(image,channel_mask);
          if ((attribute_flag[2] != 0) && (image != (Image *) NULL))
            virtual_pixel=SetImageVirtualPixelMethod(image,virtual_pixel,
              exception);
          coordinates=(double *) RelinquishMagickMemory(coordinates);
          break;
        }
        case 120:  /* Function */
        {
          AV
            *av;

          double
            *parameters;

          MagickFunction
            function;

          size_t
            number_parameters;

          VirtualPixelMethod
            virtual_pixel;

          if (attribute_flag[0] == 0)
            break;
          function=UndefinedFunction;
          if (attribute_flag[1] != 0)
            function=(MagickFunction) argument_list[1].integer_reference;
          av=(AV *) argument_list[0].array_reference;
          number_parameters=(size_t) av_len(av)+1;
          parameters=(double *) AcquireQuantumMemory(number_parameters,
            sizeof(*parameters));
          if (parameters == (double *) NULL)
            {
              ThrowPerlException(exception,ResourceLimitFatalError,
                "MemoryAllocationFailed",PackageName);
              goto PerlException;
            }
          for (j=0; j < (ssize_t) number_parameters; j++)
            parameters[j]=(double) SvNV(*(av_fetch(av,j,0)));
          virtual_pixel=UndefinedVirtualPixelMethod;
          if (attribute_flag[2] != 0)
            virtual_pixel=SetImageVirtualPixelMethod(image,(VirtualPixelMethod)
              argument_list[2].integer_reference,exception);
          (void) FunctionImage(image,function,number_parameters,parameters,
            exception);
          if ((attribute_flag[2] != 0) && (image != (Image *) NULL))
            virtual_pixel=SetImageVirtualPixelMethod(image,virtual_pixel,
              exception);
          parameters=(double *) RelinquishMagickMemory(parameters);
          break;
        }
        case 121:  /* SelectiveBlur */
        {
          if (attribute_flag[0] != 0)
            {
              flags=ParseGeometry(argument_list[0].string_reference,
                &geometry_info);
              if ((flags & SigmaValue) == 0)
                geometry_info.sigma=1.0;
              if ((flags & PercentValue) != 0)
                geometry_info.xi=QuantumRange*geometry_info.xi/100.0;
            }
          if (attribute_flag[1] != 0)
            geometry_info.rho=argument_list[1].real_reference;
          if (attribute_flag[2] != 0)
            geometry_info.sigma=argument_list[2].real_reference;
          if (attribute_flag[3] != 0)
            geometry_info.xi=argument_list[3].integer_reference;;
          if (attribute_flag[5] != 0)
            channel=(ChannelType) argument_list[5].integer_reference;
          channel_mask=SetImageChannelMask(image,channel);
          image=SelectiveBlurImage(image,geometry_info.rho,geometry_info.sigma,
            geometry_info.xi,exception);
          if (image != (Image *) NULL)
            (void) SetImageChannelMask(image,channel_mask);
          break;
        }
        case 122:  /* HaldClut */
        {
          if (attribute_flag[0] == 0)
            {
              ThrowPerlException(exception,OptionError,"ClutImageRequired",
                PackageName);
              goto PerlException;
            }
          if (attribute_flag[1] != 0)
            channel=(ChannelType) argument_list[1].integer_reference;
          channel_mask=SetImageChannelMask(image,channel);
          (void) HaldClutImage(image,argument_list[0].image_reference,
            exception);
          (void) SetImageChannelMask(image,channel_mask);
          break;
        }
        case 123:  /* BlueShift */
        {
          if (attribute_flag[0] != 0)
            (void) ParseGeometry(argument_list[0].string_reference,
              &geometry_info);
          image=BlueShiftImage(image,geometry_info.rho,exception);
          break;
        }
        case 124:  /* ForwardFourierTransformImage */
        {
          image=ForwardFourierTransformImage(image,
            argument_list[0].integer_reference != 0 ? MagickTrue : MagickFalse,
            exception);
          break;
        }
        case 125:  /* InverseFourierTransformImage */
        {
          image=InverseFourierTransformImage(image,image->next,
            argument_list[0].integer_reference != 0 ? MagickTrue : MagickFalse,
            exception);
          break;
        }
        case 126:  /* ColorDecisionList */
        {
          if (attribute_flag[0] == 0)
            argument_list[0].string_reference=(char *) NULL;
          (void) ColorDecisionListImage(image,
            argument_list[0].string_reference,exception);
          break;
        }
        case 127:  /* AutoGamma */
        {
          if (attribute_flag[0] != 0)
            channel=(ChannelType) argument_list[0].integer_reference;
          channel_mask=SetImageChannelMask(image,channel);
          (void) AutoGammaImage(image,exception);
          (void) SetImageChannelMask(image,channel_mask);
          break;
        }
        case 128:  /* AutoLevel */
        {
          if (attribute_flag[0] != 0)
            channel=(ChannelType) argument_list[0].integer_reference;
          channel_mask=SetImageChannelMask(image,channel);
          (void) AutoLevelImage(image,exception);
          (void) SetImageChannelMask(image,channel_mask);
          break;
        }
        case 129:  /* LevelColors */
        {
          PixelInfo
            black_point,
            white_point;

          (void) QueryColorCompliance("#000000",AllCompliance,&black_point,
            exception);
          (void) QueryColorCompliance("#ffffff",AllCompliance,&white_point,
            exception);
          if (attribute_flag[1] != 0)
             (void) QueryColorCompliance(
               argument_list[1].string_reference,AllCompliance,&black_point,
               exception);
          if (attribute_flag[2] != 0)
             (void) QueryColorCompliance(
               argument_list[2].string_reference,AllCompliance,&white_point,
               exception);
          if (attribute_flag[3] != 0)
            channel=(ChannelType) argument_list[3].integer_reference;
          channel_mask=SetImageChannelMask(image,channel);
          (void) LevelImageColors(image,&black_point,&white_point,
            argument_list[0].integer_reference != 0 ? MagickTrue : MagickFalse,
            exception);
          (void) SetImageChannelMask(image,channel_mask);
          break;
        }
        case 130:  /* Clamp */
        {
          if (attribute_flag[0] != 0)
            channel=(ChannelType) argument_list[0].integer_reference;
          channel_mask=SetImageChannelMask(image,channel);
          (void) ClampImage(image,exception);
          (void) SetImageChannelMask(image,channel_mask);
          break;
        }
        case 131:  /* BrightnessContrast */
        {
          double
            brightness,
            contrast;

          brightness=0.0;
          contrast=0.0;
          if (attribute_flag[0] != 0)
            {
              flags=ParseGeometry(argument_list[0].string_reference,
                &geometry_info);
              brightness=geometry_info.rho;
              if ((flags & SigmaValue) == 0)
                contrast=geometry_info.sigma;
            }
          if (attribute_flag[1] != 0)
            brightness=argument_list[1].real_reference;
          if (attribute_flag[2] != 0)
            contrast=argument_list[2].real_reference;
          if (attribute_flag[4] != 0)
            channel=(ChannelType) argument_list[4].integer_reference;
          channel_mask=SetImageChannelMask(image,channel);
          (void) BrightnessContrastImage(image,brightness,contrast,exception);
          (void) SetImageChannelMask(image,channel_mask);
          break;
        }
        case 132:  /* Morphology */
        {
          KernelInfo
            *kernel;

          MorphologyMethod
            method;

          ssize_t
            iterations;

          if (attribute_flag[0] == 0)
            break;
          kernel=AcquireKernelInfo(argument_list[0].string_reference,exception);
          if (kernel == (KernelInfo *) NULL)
            break;
          if (attribute_flag[1] != 0)
            channel=(ChannelType) argument_list[1].integer_reference;
          method=UndefinedMorphology;
          if (attribute_flag[2] != 0)
            method=(MorphologyMethod) argument_list[2].integer_reference;
          iterations=1;
          if (attribute_flag[3] != 0)
            iterations=argument_list[3].integer_reference;
          channel_mask=SetImageChannelMask(image,channel);
          image=MorphologyImage(image,method,iterations,kernel,exception);
          if (image != (Image *) NULL)
            (void) SetImageChannelMask(image,channel_mask);
          kernel=DestroyKernelInfo(kernel);
          break;
        }
        case 133:  /* Mode */
        {
          if (attribute_flag[0] != 0)
            {
              flags=ParseGeometry(argument_list[0].string_reference,
                &geometry_info);
              if ((flags & SigmaValue) == 0)
                geometry_info.sigma=1.0;
            }
          if (attribute_flag[1] != 0)
            geometry_info.rho=argument_list[1].real_reference;
          if (attribute_flag[2] != 0)
            geometry_info.sigma=argument_list[2].real_reference;
          if (attribute_flag[3] != 0)
            channel=(ChannelType) argument_list[3].integer_reference;
          channel_mask=SetImageChannelMask(image,channel);
          image=StatisticImage(image,ModeStatistic,(size_t) geometry_info.rho,
            (size_t) geometry_info.sigma,exception);
          if (image != (Image *) NULL)
            (void) SetImageChannelMask(image,channel_mask);
          break;
        }
        case 134:  /* Statistic */
        {
          StatisticType
            statistic;

          statistic=UndefinedStatistic;
          if (attribute_flag[0] != 0)
            {
              flags=ParseGeometry(argument_list[0].string_reference,
                &geometry_info);
              if ((flags & SigmaValue) == 0)
                geometry_info.sigma=1.0;
            }
          if (attribute_flag[1] != 0)
            geometry_info.rho=argument_list[1].real_reference;
          if (attribute_flag[2] != 0)
            geometry_info.sigma=argument_list[2].real_reference;
          if (attribute_flag[3] != 0)
            channel=(ChannelType) argument_list[3].integer_reference;
          if (attribute_flag[4] != 0)
            statistic=(StatisticType) argument_list[4].integer_reference;
          channel_mask=SetImageChannelMask(image,channel);
          image=StatisticImage(image,statistic,(size_t) geometry_info.rho,
            (size_t) geometry_info.sigma,exception);
          if (image != (Image *) NULL)
            (void) SetImageChannelMask(image,channel_mask);
          break;
        }
        case 135:  /* Perceptible */
        {
          double
            epsilon;

          epsilon=MagickEpsilon;
          if (attribute_flag[0] != 0)
            epsilon=argument_list[0].real_reference;
          if (attribute_flag[1] != 0)
            channel=(ChannelType) argument_list[1].integer_reference;
          channel_mask=SetImageChannelMask(image,channel);
          (void) PerceptibleImage(image,epsilon,exception);
          (void) SetImageChannelMask(image,channel_mask);
          break;
        }
        case 136:  /* Poly */
        {
          AV
            *av;

          double
            *terms;

          size_t
            number_terms;

          if (attribute_flag[0] == 0)
            break;
          if (attribute_flag[1] != 0)
            channel=(ChannelType) argument_list[1].integer_reference;
          av=(AV *) argument_list[0].array_reference;
          number_terms=(size_t) av_len(av);
          terms=(double *) AcquireQuantumMemory(number_terms,sizeof(*terms));
          if (terms == (double *) NULL)
            {
              ThrowPerlException(exception,ResourceLimitFatalError,
                "MemoryAllocationFailed",PackageName);
              goto PerlException;
            }
          for (j=0; j < av_len(av); j++)
            terms[j]=(double) SvNV(*(av_fetch(av,j,0)));
          image=PolynomialImage(image,number_terms >> 1,terms,exception);
          terms=(double *) RelinquishMagickMemory(terms);
          break;
        }
        case 137:  /* Grayscale */
        {
          PixelIntensityMethod
            method;

          method=UndefinedPixelIntensityMethod;
          if (attribute_flag[0] != 0)
            method=(PixelIntensityMethod) argument_list[0].integer_reference;
          (void) GrayscaleImage(image,method,exception);
          break;
        }
        case 138:  /* Canny */
        {
          if (attribute_flag[0] != 0)
            {
              flags=ParseGeometry(argument_list[0].string_reference,
                &geometry_info);
              if ((flags & SigmaValue) == 0)
                geometry_info.sigma=1.0;
              if ((flags & XiValue) == 0)
                geometry_info.xi=0.10;
              if ((flags & PsiValue) == 0)
                geometry_info.psi=0.30;
              if ((flags & PercentValue) != 0)
                {
                  geometry_info.xi/=100.0;
                  geometry_info.psi/=100.0;
                }
            }
          if (attribute_flag[1] != 0)
            geometry_info.rho=argument_list[1].real_reference;
          if (attribute_flag[2] != 0)
            geometry_info.sigma=argument_list[2].real_reference;
          if (attribute_flag[3] != 0)
            geometry_info.xi=argument_list[3].real_reference;
          if (attribute_flag[4] != 0)
            geometry_info.psi=argument_list[4].real_reference;
          if (attribute_flag[5] != 0)
            channel=(ChannelType) argument_list[5].integer_reference;
          channel_mask=SetImageChannelMask(image,channel);
          image=CannyEdgeImage(image,geometry_info.rho,geometry_info.sigma,
            geometry_info.xi,geometry_info.psi,exception);
          if (image != (Image *) NULL)
            (void) SetImageChannelMask(image,channel_mask);
          break;
        }
        case 139:  /* HoughLine */
        {
          if (attribute_flag[0] != 0)
            {
              flags=ParseGeometry(argument_list[0].string_reference,
                &geometry_info);
              if ((flags & SigmaValue) == 0)
                geometry_info.sigma=geometry_info.rho;
              if ((flags & XiValue) == 0)
                geometry_info.xi=40;
            }
          if (attribute_flag[1] != 0)
            geometry_info.rho=(double) argument_list[1].integer_reference;
          if (attribute_flag[2] != 0)
            geometry_info.sigma=(double) argument_list[2].integer_reference;
          if (attribute_flag[3] != 0)
            geometry_info.xi=(double) argument_list[3].integer_reference;
          image=HoughLineImage(image,(size_t) geometry_info.rho,(size_t)
            geometry_info.sigma,(size_t) geometry_info.xi,exception);
          break;
        }
        case 140:  /* MeanShift */
        {
          if (attribute_flag[0] != 0)
            {
              flags=ParseGeometry(argument_list[0].string_reference,
                &geometry_info);
              if ((flags & SigmaValue) == 0)
                geometry_info.sigma=geometry_info.rho;
              if ((flags & XiValue) == 0)
                geometry_info.xi=0.10*QuantumRange;
              if ((flags & PercentValue) != 0)
                geometry_info.xi=QuantumRange*geometry_info.xi/100.0;
            }
          if (attribute_flag[1] != 0)
            geometry_info.rho=(double) argument_list[1].integer_reference;
          if (attribute_flag[2] != 0)
            geometry_info.sigma=(double) argument_list[2].integer_reference;
          if (attribute_flag[3] != 0)
            geometry_info.xi=(double) argument_list[3].integer_reference;
          image=MeanShiftImage(image,(size_t) geometry_info.rho,(size_t)
            geometry_info.sigma,geometry_info.xi,exception);
          break;
        }
        case 141:  /* Kuwahara */
        {
          if (attribute_flag[0] != 0)
            {
              flags=ParseGeometry(argument_list[0].string_reference,
                &geometry_info);
              if ((flags & SigmaValue) == 0)
                geometry_info.sigma=geometry_info.rho-0.5;
            }
          if (attribute_flag[1] != 0)
            geometry_info.rho=argument_list[1].real_reference;
          if (attribute_flag[2] != 0)
            geometry_info.sigma=argument_list[2].real_reference;
          if (attribute_flag[3] != 0)
            channel=(ChannelType) argument_list[3].integer_reference;
          channel_mask=SetImageChannelMask(image,channel);
          image=KuwaharaImage(image,geometry_info.rho,geometry_info.sigma,
            exception);
          if (image != (Image *) NULL)
            (void) SetImageChannelMask(image,channel_mask);
          break;
        }
        case 142:  /* ConnectedComponents */
        {
          size_t
            connectivity;

          connectivity=4;
          if (attribute_flag[0] != 0)
            connectivity=(size_t) argument_list[0].integer_reference;
          image=ConnectedComponentsImage(image,connectivity,
            (CCObjectInfo **) NULL,exception);
          break;
        }
        case 143:  /* Copy */
        {
          Image
            *source_image;

          OffsetInfo
            offset;

          RectangleInfo
            offset_geometry;

          source_image=image;
          if (attribute_flag[0] != 0)
            source_image=argument_list[0].image_reference;
          SetGeometry(source_image,&geometry);
          if (attribute_flag[1] != 0)
            flags=ParseGravityGeometry(source_image,
              argument_list[1].string_reference,&geometry,exception);
          if (attribute_flag[2] != 0)
            geometry.width=(size_t) argument_list[2].integer_reference;
          if (attribute_flag[3] != 0)
            geometry.height=(size_t) argument_list[3].integer_reference;
          if (attribute_flag[4] != 0)
            geometry.x=argument_list[4].integer_reference;
          if (attribute_flag[5] != 0)
            geometry.y=argument_list[5].integer_reference;
          if (attribute_flag[6] != 0)
            image->gravity=(GravityType) argument_list[6].integer_reference;
          SetGeometry(image,&offset_geometry);
          if (attribute_flag[7] != 0)
            flags=ParseGravityGeometry(image,argument_list[7].string_reference,
              &offset_geometry,exception);
          offset.x=offset_geometry.x;
          offset.y=offset_geometry.y;
          if (attribute_flag[8] != 0)
            offset.x=argument_list[8].integer_reference;
          if (attribute_flag[9] != 0)
            offset.y=argument_list[9].integer_reference;
          (void) CopyImagePixels(image,source_image,&geometry,&offset,
            exception);
          break;
        }
        case 144:  /* Color */
        {
          PixelInfo
            color;

          (void) QueryColorCompliance("none",AllCompliance,&color,exception);
          if (attribute_flag[0] != 0)
            (void) QueryColorCompliance(argument_list[0].string_reference,
              AllCompliance,&color,exception);
          (void) SetImageColor(image,&color,exception);
          break;
        }
        case 145:  /* WaveletDenoise */
        {
          if (attribute_flag[0] != 0)
            {
              flags=ParseGeometry(argument_list[0].string_reference,
                &geometry_info);
              if ((flags & PercentValue) != 0)
                {
                  geometry_info.rho=QuantumRange*geometry_info.rho/100.0;
                  geometry_info.sigma=QuantumRange*geometry_info.sigma/100.0;
                }
              if ((flags & SigmaValue) == 0)
                geometry_info.sigma=0.0;
            }
          if (attribute_flag[1] != 0)
            geometry_info.rho=argument_list[1].real_reference;
          if (attribute_flag[2] != 0)
            geometry_info.sigma=argument_list[2].real_reference;
          if (attribute_flag[3] != 0)
            channel=(ChannelType) argument_list[3].integer_reference;
          channel_mask=SetImageChannelMask(image,channel);
          image=WaveletDenoiseImage(image,geometry_info.rho,geometry_info.sigma,
            exception);
          if (image != (Image *) NULL)
            (void) SetImageChannelMask(image,channel_mask);
          break;
        }
        case 146:  /* Colorspace */
        {
          ColorspaceType
            colorspace;

          colorspace=sRGBColorspace;
          if (attribute_flag[0] != 0)
            colorspace=(ColorspaceType) argument_list[0].integer_reference;
          (void) TransformImageColorspace(image,colorspace,exception);
          break;
        }
        case 147:  /* AutoThreshold */
        {
          AutoThresholdMethod
            method;

          method=UndefinedThresholdMethod;
          if (attribute_flag[0] != 0)
            method=(AutoThresholdMethod) argument_list[0].integer_reference;
          (void) AutoThresholdImage(image,method,exception);
          break;
        }
        case 148:  /* RangeThreshold */
        {
          if (attribute_flag[0] != 0)
            {
              flags=ParseGeometry(argument_list[0].string_reference,
                &geometry_info);
              if ((flags & SigmaValue) == 0)
                geometry_info.sigma=geometry_info.rho;
              if ((flags & XiValue) == 0)
                geometry_info.xi=geometry_info.sigma;
              if ((flags & PsiValue) == 0)
                geometry_info.psi=geometry_info.xi;
            }
          if (attribute_flag[1] != 0)
            geometry_info.rho=argument_list[1].real_reference;
          if (attribute_flag[2] != 0)
            geometry_info.sigma=argument_list[2].real_reference;
          if (attribute_flag[3] != 0)
            geometry_info.xi=argument_list[3].real_reference;
          if (attribute_flag[4] != 0)
            geometry_info.psi=argument_list[4].real_reference;
          if (attribute_flag[5] != 0)
            channel=(ChannelType) argument_list[5].integer_reference;
          channel_mask=SetImageChannelMask(image,channel);
          (void) RangeThresholdImage(image,geometry_info.rho,
            geometry_info.sigma,geometry_info.xi,geometry_info.psi,exception);
          if (image != (Image *) NULL)
            (void) SetImageChannelMask(image,channel_mask);
          break;
        }
        case 149:  /* CLAHE */
        {
          if (attribute_flag[0] != 0)
            {
              flags=ParseGeometry(argument_list[0].string_reference,
                &geometry_info);
              flags=ParseRegionGeometry(image,argument_list[0].string_reference,
                &geometry,exception);
            }
          if (attribute_flag[1] != 0)
            geometry.width=(size_t) argument_list[1].integer_reference;
          if (attribute_flag[2] != 0)
            geometry.height=(size_t) argument_list[2].integer_reference;
          if (attribute_flag[3] != 0)
            geometry.x=argument_list[3].integer_reference;
          if (attribute_flag[4] != 0)
            geometry_info.psi=argument_list[4].real_reference;
          (void) CLAHEImage(image,geometry.width,geometry.height,(size_t)
            geometry.x,(size_t) geometry_info.psi,exception);
          break;
        }
        case 150:  /* Kmeans */
        {
          if (attribute_flag[0] != 0)
            {
              flags=ParseGeometry(argument_list[0].string_reference,
                &geometry_info);
              if ((flags & SigmaValue) == 0)
                geometry_info.sigma=100.0;
              if ((flags & XiValue) == 0)
                geometry_info.xi=0.01;
            }
          if (attribute_flag[1] != 0)
            geometry_info.rho=argument_list[1].integer_reference;
          if (attribute_flag[2] != 0)
            geometry_info.sigma=argument_list[2].integer_reference;
          if (attribute_flag[3] != 0)
            geometry_info.xi=(ChannelType) argument_list[3].real_reference;
          (void) KmeansImage(image,geometry_info.rho,geometry_info.sigma,
            geometry_info.xi,exception);
          break;
        }
        case 151:  /* ColorThreshold */
        {
          PixelInfo
            start_color,
            stop_color;

          (void) QueryColorCompliance("black",AllCompliance,&start_color,
            exception);
          (void) QueryColorCompliance("white",AllCompliance,&stop_color,
            exception);
          if (attribute_flag[0] != 0)
            (void) QueryColorCompliance(argument_list[0].string_reference,
              AllCompliance,&start_color,exception);
          if (attribute_flag[1] != 0)
            (void) QueryColorCompliance(argument_list[1].string_reference,
              AllCompliance,&stop_color,exception);
          channel_mask=SetImageChannelMask(image,channel);
          (void) ColorThresholdImage(image,&start_color,&stop_color,exception);
          (void) SetImageChannelMask(image,channel_mask);
          break;
        }
        case 152:  /* WhiteBalance */
        {
          (void) WhiteBalanceImage(image,exception);
          break;
        }
        case 153:  /* BilateralBlur */
        {
          if (attribute_flag[0] != 0)
            {
              flags=ParseGeometry(argument_list[0].string_reference,
                &geometry_info);
              if ((flags & SigmaValue) == 0)
                geometry_info.sigma=geometry_info.rho;
              if ((flags & XiValue) == 0)
                geometry_info.xi=2.0*sqrt(geometry_info.rho*geometry_info.rho+
                  geometry_info.sigma*geometry_info.sigma);
              if ((flags & PsiValue) == 0)
                geometry_info.psi=0.5*sqrt(geometry_info.rho*geometry_info.rho+
                  geometry_info.sigma*geometry_info.sigma);
            }
          if (attribute_flag[1] != 0)
            geometry_info.rho=argument_list[1].integer_reference;
          if (attribute_flag[2] != 0)
            geometry_info.sigma=argument_list[2].integer_reference;
          if (attribute_flag[3] != 0)
            geometry_info.xi=argument_list[3].real_reference;
          if (attribute_flag[4] != 0)
            geometry_info.psi=argument_list[4].real_reference;
          if (attribute_flag[5] != 0)
            channel=(ChannelType) argument_list[5].integer_reference;
          channel_mask=SetImageChannelMask(image,channel);
          image=BilateralBlurImage(image,(size_t) geometry_info.rho,(size_t)
            geometry_info.sigma,geometry_info.xi,geometry_info.psi,exception);
          if (image != (Image *) NULL)
            (void) SetImageChannelMask(image,channel_mask);
          break;
        }
        case 154:  /* SortPixels */
        {
          (void) SortImagePixels(image,exception);
          break;
        }
        case 155:  /* Integral */
        {
          image=IntegralImage(image,exception);
          break;
        }
      }
      if (next != (Image *) NULL)
        (void) CatchImageException(next);
      if ((region_info.width*region_info.height) != 0)
        (void) SetImageRegionMask(image,WritePixelMask,
          (const RectangleInfo *) NULL,exception);
      if (image != (Image *) NULL)
        {
          number_images++;
          if (next && (next != image))
            {
              image->next=next->next;
              if (image->next != (Image *) NULL)
                image->next->previous=image;
              DeleteImageFromRegistry(*pv,next);
            }
          sv_setiv(*pv,PTR2IV(image));
          next=image;
        }
      if (*pv)
        pv++;
    }

  PerlException:
    if (reference_vector)
      reference_vector=(SV **) RelinquishMagickMemory(reference_vector);
    InheritPerlException(exception,perl_exception);
    exception=DestroyExceptionInfo(exception);
    sv_setiv(perl_exception,(IV) number_images);
    SvPOK_on(perl_exception);
    ST(0)=sv_2mortal(perl_exception);
    XSRETURN(1);
  }

#
###############################################################################
#                                                                             #
#                                                                             #
#                                                                             #
#   M o n t a g e                                                             #
#                                                                             #
#                                                                             #
#                                                                             #
###############################################################################
#
#
void
Montage(ref,...)
  Image::Magick ref=NO_INIT
  ALIAS:
    MontageImage  = 1
    montage       = 2
    montageimage  = 3
  PPCODE:
  {
    AV
      *av;

    char
      *attribute;

    ExceptionInfo
      *exception;

    HV
      *hv;

    Image
      *image,
      *next;

    PixelInfo
      transparent_color;

    MontageInfo
      *montage_info;

    ssize_t
      i,
      sp;

    struct PackageInfo
      *info;

    SV
      *av_reference,
      *perl_exception,
      *reference,
      *rv,
      *sv;

    PERL_UNUSED_VAR(ref);
    PERL_UNUSED_VAR(ix);
    exception=AcquireExceptionInfo();
    perl_exception=newSVpv("",0);
    sv=NULL;
    attribute=NULL;
    if (sv_isobject(ST(0)) == 0)
      {
        ThrowPerlException(exception,OptionError,"ReferenceIsNotMyType",
          PackageName);
        goto PerlException;
      }
    reference=SvRV(ST(0));
    hv=SvSTASH(reference);
    av=newAV();
    av_reference=sv_2mortal(sv_bless(newRV((SV *) av),hv));
    SvREFCNT_dec(av);
    image=SetupList(aTHX_ reference,&info,(SV ***) NULL,exception);
    if (image == (Image *) NULL)
      {
        ThrowPerlException(exception,OptionError,"NoImagesDefined",
          PackageName);
        goto PerlException;
      }
    /*
      Get options.
    */
    info=GetPackageInfo(aTHX_ (void *) av,info,exception);
    montage_info=CloneMontageInfo(info->image_info,(MontageInfo *) NULL);
    (void) QueryColorCompliance("none",AllCompliance,&transparent_color,
      exception);
    for (i=2; i < items; i+=2)
    {
      attribute=(char *) SvPV(ST(i-1),na);
      switch (*attribute)
      {
        case 'B':
        case 'b':
        {
          if (LocaleCompare(attribute,"background") == 0)
            {
              (void) QueryColorCompliance(SvPV(ST(i),na),AllCompliance,
                &montage_info->background_color,exception);
              for (next=image; next; next=next->next)
                next->background_color=montage_info->background_color;
              break;
            }
          if (LocaleCompare(attribute,"border") == 0)
            {
              montage_info->border_width=(size_t) SvIV(ST(i));
              break;
            }
          if (LocaleCompare(attribute,"bordercolor") == 0)
            {
              (void) QueryColorCompliance(SvPV(ST(i),na),AllCompliance,
                &montage_info->border_color,exception);
              for (next=image; next; next=next->next)
                next->border_color=montage_info->border_color;
              break;
            }
          if (LocaleCompare(attribute,"borderwidth") == 0)
            {
              montage_info->border_width=(size_t) SvIV(ST(i));
              break;
            }
          ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
            attribute);
          break;
        }
        case 'C':
        case 'c':
        {
          if (LocaleCompare(attribute,"compose") == 0)
            {
              sp=!SvPOK(ST(i)) ? SvIV(ST(i)) : ParseCommandOption(
                MagickComposeOptions,MagickFalse,SvPV(ST(i),na));
              if (sp < 0)
                {
                  ThrowPerlException(exception,OptionError,"UnrecognizedType",
                    SvPV(ST(i),na));
                  break;
                }
              for (next=image; next; next=next->next)
                next->compose=(CompositeOperator) sp;
              break;
            }
          ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
            attribute);
          break;
        }
        case 'F':
        case 'f':
        {
          if (LocaleCompare(attribute,"fill") == 0)
            {
              (void) QueryColorCompliance(SvPV(ST(i),na),AllCompliance,
                &montage_info->fill,exception);
              break;
            }
          if (LocaleCompare(attribute,"font") == 0)
            {
              (void) CloneString(&montage_info->font,SvPV(ST(i),na));
              break;
            }
          if (LocaleCompare(attribute,"frame") == 0)
            {
              char
                *p;

              p=SvPV(ST(i),na);
              if (IsGeometry(p) == MagickFalse)
                {
                  ThrowPerlException(exception,OptionError,"MissingGeometry",
                    p);
                  break;
                }
              (void) CloneString(&montage_info->frame,p);
              if (*p == '\0')
                montage_info->frame=(char *) NULL;
              break;
            }
          ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
            attribute);
          break;
        }
        case 'G':
        case 'g':
        {
          if (LocaleCompare(attribute,"geometry") == 0)
            {
              char
                *p;

              p=SvPV(ST(i),na);
              if (IsGeometry(p) == MagickFalse)
                {
                  ThrowPerlException(exception,OptionError,"MissingGeometry",
                    p);
                  break;
                }
             (void) CloneString(&montage_info->geometry,p);
             if (*p == '\0')
               montage_info->geometry=(char *) NULL;
             break;
           }
         if (LocaleCompare(attribute,"gravity") == 0)
           {
             ssize_t
               in;

             in=!SvPOK(ST(i)) ? SvIV(ST(i)) : ParseCommandOption(
               MagickGravityOptions,MagickFalse,SvPV(ST(i),na));
             if (in < 0)
               {
                 ThrowPerlException(exception,OptionError,"UnrecognizedType",
                   SvPV(ST(i),na));
                 return;
               }
             montage_info->gravity=(GravityType) in;
             for (next=image; next; next=next->next)
               next->gravity=(GravityType) in;
             break;
           }
          ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
            attribute);
          break;
        }
        case 'L':
        case 'l':
        {
          if (LocaleCompare(attribute,"label") == 0)
            {
              for (next=image; next; next=next->next)
                (void) SetImageProperty(next,"label",InterpretImageProperties(
                  info ? info->image_info : (ImageInfo *) NULL,next,
                  SvPV(ST(i),na),exception),exception);
              break;
            }
          ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
            attribute);
          break;
        }
        case 'M':
        case 'm':
        {
          if (LocaleCompare(attribute,"mattecolor") == 0)
            {
              (void) QueryColorCompliance(SvPV(ST(i),na),AllCompliance,
                &montage_info->alpha_color,exception);
              for (next=image; next; next=next->next)
                next->alpha_color=montage_info->alpha_color;
              break;
            }
          if (LocaleCompare(attribute,"mode") == 0)
            {
              ssize_t
                in;

              in=!SvPOK(ST(i)) ? SvIV(ST(i)) : ParseCommandOption(
                MagickModeOptions,MagickFalse,SvPV(ST(i),na));
              switch (in)
              {
                default:
                {
                  ThrowPerlException(exception,OptionError,
                    "UnrecognizedModeType",SvPV(ST(i),na));
                  break;
                }
                case FrameMode:
                {
                  (void) CloneString(&montage_info->frame,"15x15+3+3");
                  montage_info->shadow=MagickTrue;
                  break;
                }
                case UnframeMode:
                {
                  montage_info->frame=(char *) NULL;
                  montage_info->shadow=MagickFalse;
                  montage_info->border_width=0;
                  break;
                }
                case ConcatenateMode:
                {
                  montage_info->frame=(char *) NULL;
                  montage_info->shadow=MagickFalse;
                  (void) CloneString(&montage_info->geometry,"+0+0");
                  montage_info->border_width=0;
                }
              }
              break;
            }
          ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
            attribute);
          break;
        }
        case 'P':
        case 'p':
        {
          if (LocaleCompare(attribute,"pointsize") == 0)
            {
              montage_info->pointsize=SvIV(ST(i));
              break;
            }
          ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
            attribute);
          break;
        }
        case 'S':
        case 's':
        {
          if (LocaleCompare(attribute,"shadow") == 0)
            {
              sp=!SvPOK(ST(i)) ? SvIV(ST(i)) : ParseCommandOption(
                MagickBooleanOptions,MagickFalse,SvPV(ST(i),na));
              if (sp < 0)
                {
                  ThrowPerlException(exception,OptionError,"UnrecognizedType",
                    SvPV(ST(i),na));
                  break;
                }
             montage_info->shadow=sp != 0 ? MagickTrue : MagickFalse;
             break;
            }
          if (LocaleCompare(attribute,"stroke") == 0)
            {
              (void) QueryColorCompliance(SvPV(ST(i),na),AllCompliance,
                &montage_info->stroke,exception);
              break;
            }
          ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
            attribute);
          break;
        }
        case 'T':
        case 't':
        {
          if (LocaleCompare(attribute,"texture") == 0)
            {
              (void) CloneString(&montage_info->texture,SvPV(ST(i),na));
              break;
            }
          if (LocaleCompare(attribute,"tile") == 0)
            {
              char *p=SvPV(ST(i),na);
              if (IsGeometry(p) == MagickFalse)
                {
                  ThrowPerlException(exception,OptionError,"MissingGeometry",
                    p);
                  break;
                }
              (void) CloneString(&montage_info->tile,p);
              if (*p == '\0')
                montage_info->tile=(char *) NULL;
              break;
            }
          if (LocaleCompare(attribute,"title") == 0)
            {
              (void) CloneString(&montage_info->title,SvPV(ST(i),na));
              break;
            }
          if (LocaleCompare(attribute,"transparent") == 0)
            {
              PixelInfo
                transparent_color;

              QueryColorCompliance(SvPV(ST(i),na),AllCompliance,
                &transparent_color,exception);
              for (next=image; next; next=next->next)
                (void) TransparentPaintImage(next,&transparent_color,
                  TransparentAlpha,MagickFalse,exception);
              break;
            }
          ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
            attribute);
          break;
        }
        default:
        {
          ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
            attribute);
          break;
        }
      }
    }
    image=MontageImageList(info->image_info,montage_info,image,exception);
    montage_info=DestroyMontageInfo(montage_info);
    if (image == (Image *) NULL)
      goto PerlException;
    if (transparent_color.alpha != TransparentAlpha)
      for (next=image; next; next=next->next)
        (void) TransparentPaintImage(next,&transparent_color,
          TransparentAlpha,MagickFalse,exception);
    for (  ; image; image=image->next)
    {
      AddImageToRegistry(sv,image);
      rv=newRV(sv);
      av_push(av,sv_bless(rv,hv));
      SvREFCNT_dec(sv);
    }
    exception=DestroyExceptionInfo(exception);
    ST(0)=av_reference;
    SvREFCNT_dec(perl_exception);
    XSRETURN(1);

  PerlException:
    InheritPerlException(exception,perl_exception);
    exception=DestroyExceptionInfo(exception);
    sv_setiv(perl_exception,(IV) SvCUR(perl_exception) != 0);
    SvPOK_on(perl_exception);
    ST(0)=sv_2mortal(perl_exception);
    XSRETURN(1);
  }

#
###############################################################################
#                                                                             #
#                                                                             #
#                                                                             #
#   M o r p h                                                                 #
#                                                                             #
#                                                                             #
#                                                                             #
###############################################################################
#
#
void
Morph(ref,...)
  Image::Magick ref=NO_INIT
  ALIAS:
    MorphImage  = 1
    morph       = 2
    morphimage  = 3
  PPCODE:
  {
    AV
      *av;

    char
      *attribute;

    ExceptionInfo
      *exception;

    HV
      *hv;

    Image
      *image;

    ssize_t
      i,
      number_frames;

    struct PackageInfo
      *info;

    SV
      *av_reference,
      *perl_exception,
      *reference,
      *rv,
      *sv;

    PERL_UNUSED_VAR(ref);
    PERL_UNUSED_VAR(ix);
    exception=AcquireExceptionInfo();
    perl_exception=newSVpv("",0);
    sv=NULL;
    av=NULL;
    attribute=NULL;
    if (sv_isobject(ST(0)) == 0)
      {
        ThrowPerlException(exception,OptionError,"ReferenceIsNotMyType",
          PackageName);
        goto PerlException;
      }
    reference=SvRV(ST(0));
    hv=SvSTASH(reference);
    av=newAV();
    av_reference=sv_2mortal(sv_bless(newRV((SV *) av),hv));
    SvREFCNT_dec(av);
    image=SetupList(aTHX_ reference,&info,(SV ***) NULL,exception);
    if (image == (Image *) NULL)
      {
        ThrowPerlException(exception,OptionError,"NoImagesDefined",
          PackageName);
        goto PerlException;
      }
    info=GetPackageInfo(aTHX_ (void *) av,info,exception);
    /*
      Get attribute.
    */
    number_frames=30;
    for (i=2; i < items; i+=2)
    {
      attribute=(char *) SvPV(ST(i-1),na);
      switch (*attribute)
      {
        case 'F':
        case 'f':
        {
          if (LocaleCompare(attribute,"frames") == 0)
            {
              number_frames=SvIV(ST(i));
              break;
            }
          ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
            attribute);
          break;
        }
        default:
        {
          ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
            attribute);
          break;
        }
      }
    }
    image=MorphImages(image,(size_t) number_frames,exception);
    if (image == (Image *) NULL)
      goto PerlException;
    for ( ; image; image=image->next)
    {
      AddImageToRegistry(sv,image);
      rv=newRV(sv);
      av_push(av,sv_bless(rv,hv));
      SvREFCNT_dec(sv);
    }
    exception=DestroyExceptionInfo(exception);
    ST(0)=av_reference;
    SvREFCNT_dec(perl_exception);  /* can't return warning messages */
    XSRETURN(1);

  PerlException:
    InheritPerlException(exception,perl_exception);
    exception=DestroyExceptionInfo(exception);
    sv_setiv(perl_exception,(IV) SvCUR(perl_exception) != 0);
    SvPOK_on(perl_exception);
    ST(0)=sv_2mortal(perl_exception);
    XSRETURN(1);
  }

#
###############################################################################
#                                                                             #
#                                                                             #
#                                                                             #
#   M o s a i c                                                               #
#                                                                             #
#                                                                             #
#                                                                             #
###############################################################################
#
#
void
Mosaic(ref)
  Image::Magick ref=NO_INIT
  ALIAS:
    MosaicImage   = 1
    mosaic        = 2
    mosaicimage   = 3
  PPCODE:
  {
    AV
      *av;

    ExceptionInfo
      *exception;

    HV
      *hv;

    Image
      *image;

    struct PackageInfo
      *info;

    SV
      *perl_exception,
      *reference,
      *rv,
      *sv;

    PERL_UNUSED_VAR(ref);
    PERL_UNUSED_VAR(ix);
    exception=AcquireExceptionInfo();
    perl_exception=newSVpv("",0);
    sv=NULL;
    if (sv_isobject(ST(0)) == 0)
      {
        ThrowPerlException(exception,OptionError,"ReferenceIsNotMyType",
          PackageName);
        goto PerlException;
      }
    reference=SvRV(ST(0));
    hv=SvSTASH(reference);
    image=SetupList(aTHX_ reference,&info,(SV ***) NULL,exception);
    if (image == (Image *) NULL)
      {
        ThrowPerlException(exception,OptionError,"NoImagesDefined",
          PackageName);
        goto PerlException;
      }
    image=MergeImageLayers(image,MosaicLayer,exception);
    /*
      Create blessed Perl array for the returned image.
    */
    av=newAV();
    ST(0)=sv_2mortal(sv_bless(newRV((SV *) av),hv));
    SvREFCNT_dec(av);
    AddImageToRegistry(sv,image);
    rv=newRV(sv);
    av_push(av,sv_bless(rv,hv));
    SvREFCNT_dec(sv);
    (void) CopyMagickString(info->image_info->filename,image->filename,
      MagickPathExtent);
    SetImageInfo(info->image_info,0,exception);
    exception=DestroyExceptionInfo(exception);
    SvREFCNT_dec(perl_exception);
    XSRETURN(1);

  PerlException:
    InheritPerlException(exception,perl_exception);
    exception=DestroyExceptionInfo(exception);
    sv_setiv(perl_exception,(IV) SvCUR(perl_exception) != 0);
    SvPOK_on(perl_exception);  /* return messages in string context */
    ST(0)=sv_2mortal(perl_exception);
    XSRETURN(1);
  }

#
###############################################################################
#                                                                             #
#                                                                             #
#                                                                             #
#   P e r c e p t u a l H a s h                                               #
#                                                                             #
#                                                                             #
#                                                                             #
###############################################################################
#
#
void
PerceptualHash(ref)
  Image::Magick ref = NO_INIT
  ALIAS:
    PerceptualHashImage = 1
    perceptualhash      = 2
    perceptualhashimage = 3
  PPCODE:
  {
    AV
      *av;

    ChannelPerceptualHash
      *channel_phash;

    char
      message[MagickPathExtent];

    ExceptionInfo
      *exception;

    Image
      *image;

    ssize_t
      count;

    struct PackageInfo
      *info;

    SV
      *perl_exception,
      *reference;

    PERL_UNUSED_VAR(ref);
    PERL_UNUSED_VAR(ix);
    exception=AcquireExceptionInfo();
    perl_exception=newSVpv("",0);
    av=NULL;
    if (sv_isobject(ST(0)) == 0)
      {
        ThrowPerlException(exception,OptionError,"ReferenceIsNotMyType",
          PackageName);
        goto PerlException;
      }
    reference=SvRV(ST(0));
    av=newAV();
    SvREFCNT_dec(av);
    image=SetupList(aTHX_ reference,&info,(SV ***) NULL,exception);
    if (image == (Image *) NULL)
      {
        ThrowPerlException(exception,OptionError,"NoImagesDefined",
          PackageName);
        goto PerlException;
      }
    count=0;
    for ( ; image; image=image->next)
    {
      ssize_t
        i;

      channel_phash=GetImagePerceptualHash(image,exception);
      if (channel_phash == (ChannelPerceptualHash *) NULL)
        continue;
      count++;
      for (i=0; i < (ssize_t) GetPixelChannels(image); i++)
      {
        ssize_t
          j;

        PixelChannel channel=GetPixelChannelChannel(image,i);
        PixelTrait traits=GetPixelChannelTraits(image,channel);
        if (traits == UndefinedPixelTrait)
          continue;
        EXTEND(sp,((ssize_t) GetPixelChannels(image)*
          MaximumNumberOfPerceptualHashes*
          (ssize_t) channel_phash[0].number_colorspaces*(i+1)*count));
        for (j=0; j < MaximumNumberOfPerceptualHashes; j++)
        {
          ssize_t
            k;

          for (k=0; k < (ssize_t) channel_phash[0].number_colorspaces; k++)
          {
            (void) FormatLocaleString(message,MagickPathExtent,"%.20g",
              channel_phash[channel].phash[k][j]);
            PUSHs(sv_2mortal(newSVpv(message,0)));
          }
        }
      }
      channel_phash=(ChannelPerceptualHash *)
        RelinquishMagickMemory(channel_phash);
    }

  PerlException:
    InheritPerlException(exception,perl_exception);
    exception=DestroyExceptionInfo(exception);
    SvREFCNT_dec(perl_exception);
  }

#
###############################################################################
#                                                                             #
#                                                                             #
#                                                                             #
#   P i n g                                                                   #
#                                                                             #
#                                                                             #
#                                                                             #
###############################################################################
#
#
void
Ping(ref,...)
  Image::Magick ref=NO_INIT
  ALIAS:
    PingImage  = 1
    ping       = 2
    pingimage  = 3
  PPCODE:
  {
    AV
      *av;

    char
      **keep,
      **list,
      **p;

    ExceptionInfo
      *exception;

    Image
      *image,
      *next;

    int
      n;

    MagickBooleanType
      status;

    ssize_t
      ac,
      i;

    STRLEN
      *length;

    struct PackageInfo
      *info,
      *package_info;

    SV
      *perl_exception,
      *reference;

    size_t
      count;

    PERL_UNUSED_VAR(ref);
    PERL_UNUSED_VAR(ix);
    exception=AcquireExceptionInfo();
    perl_exception=newSVpv("",0);
    package_info=(struct PackageInfo *) NULL;
    ac=(items < 2) ? 1 : items-1;
    list=(char **) AcquireQuantumMemory((size_t) ac+1UL,sizeof(*list));
    keep=list;
    length=(STRLEN *) NULL;
    if (list == (char **) NULL)
      {
        ThrowPerlException(exception,ResourceLimitError,
          "MemoryAllocationFailed",PackageName);
        goto PerlException;
      }
    keep=list;
    length=(STRLEN *) AcquireQuantumMemory((size_t) ac+1UL,sizeof(*length));
    if (length == (STRLEN *) NULL)
      {
        ThrowPerlException(exception,ResourceLimitError,
          "MemoryAllocationFailed",PackageName);
        goto PerlException;
      }
    if (sv_isobject(ST(0)) == 0)
      {
        ThrowPerlException(exception,OptionError,"ReferenceIsNotMyType",
          PackageName);
        goto PerlException;
      }
    reference=SvRV(ST(0));
    if (SvTYPE(reference) != SVt_PVAV)
      {
        ThrowPerlException(exception,OptionError,"ReferenceIsNotMyType",
          PackageName);
        goto PerlException;
      }
    av=(AV *) reference;
    info=GetPackageInfo(aTHX_ (void *) av,(struct PackageInfo *) NULL,
      exception);
    package_info=ClonePackageInfo(info,exception);
    n=1;
    if (items <= 1)
      *list=(char *) (*package_info->image_info->filename ?
        package_info->image_info->filename : "XC:black");
    else
      for (n=0, i=0; i < ac; i++)
      {
        list[n]=(char *) SvPV(ST(i+1),length[n]);
        if ((items >= 3) && strEQcase(list[n],"blob"))
          {
            void
              *blob;

            i++;
            blob=(void *) (SvPV(ST(i+1),length[n]));
            SetImageInfoBlob(package_info->image_info,blob,(size_t) length[n]);
          }
        if ((items >= 3) && strEQcase(list[n],"filename"))
          continue;
        if ((items >= 3) && strEQcase(list[n],"file"))
          {
            FILE
              *file;

            PerlIO
              *io_info;

            i++;
            io_info=IoIFP(sv_2io(ST(i+1)));
            if (io_info == (PerlIO *) NULL)
              {
                ThrowPerlException(exception,BlobError,"UnableToOpenFile",
                  PackageName);
                continue;
              }
            file=PerlIO_findFILE(io_info);
            if (file == (FILE *) NULL)
              {
                ThrowPerlException(exception,BlobError,"UnableToOpenFile",
                  PackageName);
                continue;
              }
            SetImageInfoFile(package_info->image_info,file);
          }
        if ((items >= 3) && strEQcase(list[n],"magick"))
          continue;
        n++;
      }
    list[n]=(char *) NULL;
    keep=list;
    status=ExpandFilenames(&n,&list);
    if (status == MagickFalse)
      {
        ThrowPerlException(exception,ResourceLimitError,
          "MemoryAllocationFailed",PackageName);
        goto PerlException;
      }
    count=0;
    for (i=0; i < n; i++)
    {
      (void) CopyMagickString(package_info->image_info->filename,list[i],
        MagickPathExtent);
      image=PingImage(package_info->image_info,exception);
      if (image == (Image *) NULL)
        break;
      if ((package_info->image_info->file != (FILE *) NULL) ||
          (package_info->image_info->blob != (void *) NULL))
        DisassociateImageStream(image);
      count+=GetImageListLength(image);
      EXTEND(sp,4*(ssize_t) count);
      for (next=image; next; next=next->next)
      {
        PUSHs(sv_2mortal(newSViv((ssize_t) next->columns)));
        PUSHs(sv_2mortal(newSViv((ssize_t) next->rows)));
        PUSHs(sv_2mortal(newSViv((ssize_t) GetBlobSize(next))));
        PUSHs(sv_2mortal(newSVpv(next->magick,0)));
      }
      image=DestroyImageList(image);
    }
    /*
      Free resources.
    */
    for (i=0; i < n; i++)
      if (list[i] != (char *) NULL)
        for (p=keep; list[i] != *p++; )
          if (*p == NULL)
            {
              list[i]=(char *) RelinquishMagickMemory(list[i]);
              break;
            }

  PerlException:
    if (package_info != (struct PackageInfo *) NULL)
      DestroyPackageInfo(package_info);
    if (list && (list != keep))
      list=(char **) RelinquishMagickMemory(list);
    if (keep)
      keep=(char **) RelinquishMagickMemory(keep);
    if (length)
      length=(STRLEN *) RelinquishMagickMemory(length);
    InheritPerlException(exception,perl_exception);
    exception=DestroyExceptionInfo(exception);
    SvREFCNT_dec(perl_exception);  /* throw away all errors */
  }

#
###############################################################################
#                                                                             #
#                                                                             #
#                                                                             #
#   P r e v i e w                                                             #
#                                                                             #
#                                                                             #
#                                                                             #
###############################################################################
#
#
void
Preview(ref,...)
  Image::Magick ref=NO_INIT
  ALIAS:
    PreviewImage = 1
    preview      = 2
    previewimage = 3
  PPCODE:
  {
    AV
      *av;

    ExceptionInfo
      *exception;

    HV
      *hv;

    Image
      *image,
      *preview_image;

    PreviewType
      preview_type;

    struct PackageInfo
      *info;

    SV
      *av_reference,
      *perl_exception,
      *reference,
      *rv,
      *sv;

    PERL_UNUSED_VAR(ref);
    PERL_UNUSED_VAR(ix);
    exception=AcquireExceptionInfo();
    perl_exception=newSVpv("",0);
    sv=NULL;
    av=NULL;
    if (sv_isobject(ST(0)) == 0)
      {
        ThrowPerlException(exception,OptionError,"ReferenceIsNotMyType",
          PackageName);
        goto PerlException;
      }
    reference=SvRV(ST(0));
    hv=SvSTASH(reference);
    av=newAV();
    av_reference=sv_2mortal(sv_bless(newRV((SV *) av),hv));
    SvREFCNT_dec(av);
    image=SetupList(aTHX_ reference,&info,(SV ***) NULL,exception);
    if (image == (Image *) NULL)
      {
        ThrowPerlException(exception,OptionError,"NoImagesDefined",
          PackageName);
        goto PerlException;
      }
    info=GetPackageInfo(aTHX_ (void *) av,info,exception);
    preview_type=GammaPreview;
    if (items > 1)
      preview_type=(PreviewType)
        ParseCommandOption(MagickPreviewOptions,MagickFalse,SvPV(ST(1),na));
    for ( ; image; image=image->next)
    {
      preview_image=PreviewImage(image,preview_type,exception);
      if (preview_image == (Image *) NULL)
        goto PerlException;
      AddImageToRegistry(sv,preview_image);
      rv=newRV(sv);
      av_push(av,sv_bless(rv,hv));
      SvREFCNT_dec(sv);
    }
    exception=DestroyExceptionInfo(exception);
    ST(0)=av_reference;
    SvREFCNT_dec(perl_exception);  /* can't return warning messages */
    XSRETURN(1);

  PerlException:
    InheritPerlException(exception,perl_exception);
    exception=DestroyExceptionInfo(exception);
    sv_setiv(perl_exception,(IV) SvCUR(perl_exception) != 0);
    SvPOK_on(perl_exception);
    ST(0)=sv_2mortal(perl_exception);
    XSRETURN(1);
  }

#
###############################################################################
#                                                                             #
#                                                                             #
#                                                                             #
#   Q u e r y C o l o r                                                       #
#                                                                             #
#                                                                             #
#                                                                             #
###############################################################################
#
#
void
QueryColor(ref,...)
  Image::Magick ref=NO_INIT
  ALIAS:
    querycolor = 1
  PPCODE:
  {
    char
      *name;

    ExceptionInfo
      *exception;

    PixelInfo
      color;

    ssize_t
      i;

    SV
      *perl_exception;

    PERL_UNUSED_VAR(ref);
    PERL_UNUSED_VAR(ix);
    exception=AcquireExceptionInfo();
    perl_exception=newSVpv("",0);
    if (items == 1)
      {
        const ColorInfo
          **colorlist;

        size_t
          colors;

        colorlist=GetColorInfoList("*",&colors,exception);
        EXTEND(sp,(ssize_t) colors);
        for (i=0; i < (ssize_t) colors; i++)
        {
          PUSHs(sv_2mortal(newSVpv(colorlist[i]->name,0)));
        }
        colorlist=(const ColorInfo **)
          RelinquishMagickMemory((ColorInfo **) colorlist);
        goto PerlException;
      }
    EXTEND(sp,5*items);
    for (i=1; i < items; i++)
    {
      name=(char *) SvPV(ST(i),na);
      if (QueryColorCompliance(name,AllCompliance,&color,exception) == MagickFalse)
        {
          PUSHs(&sv_undef);
          continue;
        }
      PUSHs(sv_2mortal(newSViv((ssize_t) floor(color.red+0.5))));
      PUSHs(sv_2mortal(newSViv((ssize_t) floor(color.green+0.5))));
      PUSHs(sv_2mortal(newSViv((ssize_t) floor(color.blue+0.5))));
      if (color.colorspace == CMYKColorspace)
        PUSHs(sv_2mortal(newSViv((ssize_t) floor(color.black+0.5))));
      if (color.alpha_trait != UndefinedPixelTrait)
        PUSHs(sv_2mortal(newSViv((ssize_t) floor(color.alpha+0.5))));
    }

  PerlException:
    InheritPerlException(exception,perl_exception);
    exception=DestroyExceptionInfo(exception);
    SvREFCNT_dec(perl_exception);
  }

#
###############################################################################
#                                                                             #
#                                                                             #
#                                                                             #
#   Q u e r y C o l o r N a m e                                               #
#                                                                             #
#                                                                             #
#                                                                             #
###############################################################################
#
#
void
QueryColorname(ref,...)
  Image::Magick ref=NO_INIT
  ALIAS:
    querycolorname = 1
  PPCODE:
  {
    AV
      *av;

    char
      message[MagickPathExtent];

    ExceptionInfo
      *exception;

    Image
      *image;

    PixelInfo
      target_color;

    ssize_t
      i;

    struct PackageInfo
      *info;

    SV
      *perl_exception,
      *reference;  /* reference is the SV* of ref=SvIV(reference) */

    PERL_UNUSED_VAR(ref);
    PERL_UNUSED_VAR(ix);
    exception=AcquireExceptionInfo();
    perl_exception=newSVpv("",0);
    reference=SvRV(ST(0));
    av=(AV *) reference;
    info=GetPackageInfo(aTHX_ (void *) av,(struct PackageInfo *) NULL,
      exception);
    image=SetupList(aTHX_ reference,&info,(SV ***) NULL,exception);
    if (image == (Image *) NULL)
      {
        ThrowPerlException(exception,OptionError,"NoImagesDefined",
          PackageName);
        goto PerlException;
      }
    EXTEND(sp,items);
    for (i=1; i < items; i++)
    {
      (void) QueryColorCompliance(SvPV(ST(i),na),AllCompliance,&target_color,
        exception);
      (void) QueryColorname(image,&target_color,SVGCompliance,message,
        exception);
      PUSHs(sv_2mortal(newSVpv(message,0)));
    }

  PerlException:
    InheritPerlException(exception,perl_exception);
    exception=DestroyExceptionInfo(exception);
    SvREFCNT_dec(perl_exception);
  }

#
###############################################################################
#                                                                             #
#                                                                             #
#                                                                             #
#   Q u e r y F o n t                                                         #
#                                                                             #
#                                                                             #
#                                                                             #
###############################################################################
#
#
void
QueryFont(ref,...)
  Image::Magick ref=NO_INIT
  ALIAS:
    queryfont = 1
  PPCODE:
  {
    char
      *name,
      message[MagickPathExtent];

    ExceptionInfo
      *exception;

    ssize_t
      i;

    SV
      *perl_exception;

    volatile const TypeInfo
      *type_info;

    PERL_UNUSED_VAR(ref);
    PERL_UNUSED_VAR(ix);
    exception=AcquireExceptionInfo();
    perl_exception=newSVpv("",0);
    if (items == 1)
      {
        const TypeInfo
          **typelist;

        size_t
          types;

        typelist=GetTypeInfoList("*",&types,exception);
        EXTEND(sp,(ssize_t) types);
        for (i=0; i < (ssize_t) types; i++)
        {
          PUSHs(sv_2mortal(newSVpv(typelist[i]->name,0)));
        }
        typelist=(const TypeInfo **) RelinquishMagickMemory((TypeInfo **)
          typelist);
        goto PerlException;
      }
    EXTEND(sp,10*items);
    for (i=1; i < items; i++)
    {
      name=(char *) SvPV(ST(i),na);
      type_info=GetTypeInfo(name,exception);
      if (type_info == (TypeInfo *) NULL)
        {
          PUSHs(&sv_undef);
          continue;
        }
      if (type_info->name == (char *) NULL)
        PUSHs(&sv_undef);
      else
        PUSHs(sv_2mortal(newSVpv(type_info->name,0)));
      if (type_info->description == (char *) NULL)
        PUSHs(&sv_undef);
      else
        PUSHs(sv_2mortal(newSVpv(type_info->description,0)));
      if (type_info->family == (char *) NULL)
        PUSHs(&sv_undef);
      else
        PUSHs(sv_2mortal(newSVpv(type_info->family,0)));
      if (type_info->style == UndefinedStyle)
        PUSHs(&sv_undef);
      else
        PUSHs(sv_2mortal(newSVpv(CommandOptionToMnemonic(MagickStyleOptions,
          type_info->style),0)));
      if (type_info->stretch == UndefinedStretch)
        PUSHs(&sv_undef);
      else
        PUSHs(sv_2mortal(newSVpv(CommandOptionToMnemonic(MagickStretchOptions,
          type_info->stretch),0)));
      (void) FormatLocaleString(message,MagickPathExtent,"%.20g",(double)
        type_info->weight);
      PUSHs(sv_2mortal(newSVpv(message,0)));
      if (type_info->encoding == (char *) NULL)
        PUSHs(&sv_undef);
      else
        PUSHs(sv_2mortal(newSVpv(type_info->encoding,0)));
      if (type_info->foundry == (char *) NULL)
        PUSHs(&sv_undef);
      else
        PUSHs(sv_2mortal(newSVpv(type_info->foundry,0)));
      if (type_info->format == (char *) NULL)
        PUSHs(&sv_undef);
      else
        PUSHs(sv_2mortal(newSVpv(type_info->format,0)));
      if (type_info->metrics == (char *) NULL)
        PUSHs(&sv_undef);
      else
        PUSHs(sv_2mortal(newSVpv(type_info->metrics,0)));
      if (type_info->glyphs == (char *) NULL)
        PUSHs(&sv_undef);
      else
        PUSHs(sv_2mortal(newSVpv(type_info->glyphs,0)));
    }

  PerlException:
    InheritPerlException(exception,perl_exception);
    exception=DestroyExceptionInfo(exception);
    SvREFCNT_dec(perl_exception);
  }

#
###############################################################################
#                                                                             #
#                                                                             #
#                                                                             #
#   Q u e r y F o n t M e t r i c s                                           #
#                                                                             #
#                                                                             #
#                                                                             #
###############################################################################
#
#
void
QueryFontMetrics(ref,...)
  Image::Magick ref=NO_INIT
  ALIAS:
    queryfontmetrics = 1
  PPCODE:
  {
    AffineMatrix
      affine,
      current;

    AV
      *av;

    char
      *attribute;

    double
      x,
      y;

    DrawInfo
      *draw_info;

    ExceptionInfo
      *exception;

    GeometryInfo
      geometry_info;

    Image
      *image;

    MagickBooleanType
      status;

    MagickStatusType
      flags;

    ssize_t
      i,
      type;

    struct PackageInfo
      *info,
      *package_info;

    SV
      *perl_exception,
      *reference;  /* reference is the SV* of ref=SvIV(reference) */

    TypeMetric
      metrics;

    PERL_UNUSED_VAR(ref);
    PERL_UNUSED_VAR(ix);
    exception=AcquireExceptionInfo();
    package_info=(struct PackageInfo *) NULL;
    perl_exception=newSVpv("",0);
    reference=SvRV(ST(0));
    av=(AV *) reference;
    info=GetPackageInfo(aTHX_ (void *) av,(struct PackageInfo *) NULL,
      exception);
    image=SetupList(aTHX_ reference,&info,(SV ***) NULL,exception);
    if (image == (Image *) NULL)
      {
        ThrowPerlException(exception,OptionError,"NoImagesDefined",
          PackageName);
        goto PerlException;
      }
    package_info=ClonePackageInfo(info,exception);
    draw_info=CloneDrawInfo(package_info->image_info,(DrawInfo *) NULL);
    CloneString(&draw_info->text,"");
    current=draw_info->affine;
    GetAffineMatrix(&affine);
    x=0.0;
    y=0.0;
    EXTEND(sp,7*items);
    for (i=2; i < items; i+=2)
    {
      attribute=(char *) SvPV(ST(i-1),na);
      switch (*attribute)
      {
        case 'A':
        case 'a':
        {
          if (LocaleCompare(attribute,"antialias") == 0)
            {
              type=ParseCommandOption(MagickBooleanOptions,MagickFalse,
                SvPV(ST(i),na));
              if (type < 0)
                {
                  ThrowPerlException(exception,OptionError,"UnrecognizedType",
                    SvPV(ST(i),na));
                  break;
                }
              draw_info->text_antialias=type != 0 ? MagickTrue : MagickFalse;
              break;
            }
          ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
            attribute);
          break;
        }
        case 'd':
        case 'D':
        {
          if (LocaleCompare(attribute,"density") == 0)
            {
              CloneString(&draw_info->density,SvPV(ST(i),na));
              break;
            }
          if (LocaleCompare(attribute,"direction") == 0)
            {
              draw_info->direction=(DirectionType) ParseCommandOption(
                MagickDirectionOptions,MagickFalse,SvPV(ST(i),na));
              break;
            }
          ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
            attribute);
          break;
        }
        case 'e':
        case 'E':
        {
          if (LocaleCompare(attribute,"encoding") == 0)
            {
              CloneString(&draw_info->encoding,SvPV(ST(i),na));
              break;
            }
          ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
            attribute);
          break;
        }
        case 'f':
        case 'F':
        {
          if (LocaleCompare(attribute,"family") == 0)
            {
              CloneString(&draw_info->family,SvPV(ST(i),na));
              break;
            }
          if (LocaleCompare(attribute,"fill") == 0)
            {
              if (info)
                (void) QueryColorCompliance(SvPV(ST(i),na),AllCompliance,
                  &draw_info->fill,exception);
              break;
            }
          if (LocaleCompare(attribute,"font") == 0)
            {
              CloneString(&draw_info->font,SvPV(ST(i),na));
              break;
            }
          ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
            attribute);
          break;
        }
        case 'g':
        case 'G':
        {
          if (LocaleCompare(attribute,"geometry") == 0)
            {
              CloneString(&draw_info->geometry,SvPV(ST(i),na));
              break;
            }
          if (LocaleCompare(attribute,"gravity") == 0)
            {
              draw_info->gravity=(GravityType) ParseCommandOption(
                MagickGravityOptions,MagickFalse,SvPV(ST(i),na));
              break;
            }
          ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
            attribute);
          break;
        }
        case 'i':
        case 'I':
        {
          if (LocaleCompare(attribute,"interline-spacing") == 0)
            {
              flags=ParseGeometry(SvPV(ST(i),na),&geometry_info);
              draw_info->interline_spacing=geometry_info.rho;
              break;
            }
          if (LocaleCompare(attribute,"interword-spacing") == 0)
            {
              flags=ParseGeometry(SvPV(ST(i),na),&geometry_info);
              draw_info->interword_spacing=geometry_info.rho;
              break;
            }
          ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
            attribute);
          break;
        }
        case 'k':
        case 'K':
        {
          if (LocaleCompare(attribute,"kerning") == 0)
            {
              flags=ParseGeometry(SvPV(ST(i),na),&geometry_info);
              draw_info->kerning=geometry_info.rho;
              break;
            }
          ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
            attribute);
          break;
        }
        case 'p':
        case 'P':
        {
          if (LocaleCompare(attribute,"pointsize") == 0)
            {
              flags=ParseGeometry(SvPV(ST(i),na),&geometry_info);
              draw_info->pointsize=geometry_info.rho;
              break;
            }
          ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
            attribute);
          break;
        }
        case 'r':
        case 'R':
        {
          if (LocaleCompare(attribute,"rotate") == 0)
            {
              flags=ParseGeometry(SvPV(ST(i),na),&geometry_info);
              affine.rx=geometry_info.rho;
              affine.ry=geometry_info.sigma;
              if ((flags & SigmaValue) == 0)
                affine.ry=affine.rx;
              break;
            }
          ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
            attribute);
          break;
        }
        case 's':
        case 'S':
        {
          if (LocaleCompare(attribute,"scale") == 0)
            {
              flags=ParseGeometry(SvPV(ST(i),na),&geometry_info);
              affine.sx=geometry_info.rho;
              affine.sy=geometry_info.sigma;
              if ((flags & SigmaValue) == 0)
                affine.sy=affine.sx;
              break;
            }
          if (LocaleCompare(attribute,"skew") == 0)
            {
              double
                x_angle,
                y_angle;

              flags=ParseGeometry(SvPV(ST(i),na),&geometry_info);
              x_angle=geometry_info.rho;
              y_angle=geometry_info.sigma;
              if ((flags & SigmaValue) == 0)
                y_angle=x_angle;
              affine.ry=tan(DegreesToRadians(fmod(x_angle,360.0)));
              affine.rx=tan(DegreesToRadians(fmod(y_angle,360.0)));
              break;
            }
          if (LocaleCompare(attribute,"stroke") == 0)
            {
              if (info)
                (void) QueryColorCompliance(SvPV(ST(i),na),AllCompliance,
                  &draw_info->stroke,exception);
              break;
            }
          if (LocaleCompare(attribute,"style") == 0)
            {
              type=ParseCommandOption(MagickStyleOptions,MagickFalse,
                SvPV(ST(i),na));
              if (type < 0)
                {
                  ThrowPerlException(exception,OptionError,"UnrecognizedType",
                    SvPV(ST(i),na));
                  break;
                }
              draw_info->style=(StyleType) type;
              break;
            }
          ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
            attribute);
          break;
        }
        case 't':
        case 'T':
        {
          if (LocaleCompare(attribute,"text") == 0)
            {
              CloneString(&draw_info->text,SvPV(ST(i),na));
              break;
            }
          if (LocaleCompare(attribute,"translate") == 0)
            {
              flags=ParseGeometry(SvPV(ST(i),na),&geometry_info);
              affine.tx=geometry_info.rho;
              affine.ty=geometry_info.sigma;
              if ((flags & SigmaValue) == 0)
                affine.ty=affine.tx;
              break;
            }
          ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
            attribute);
          break;
        }
        case 'w':
        case 'W':
        {
          if (LocaleCompare(attribute,"weight") == 0)
            {
              flags=ParseGeometry(SvPV(ST(i),na),&geometry_info);
              draw_info->weight=(size_t) geometry_info.rho;
              break;
            }
          ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
            attribute);
          break;
        }
        case 'x':
        case 'X':
        {
          if (LocaleCompare(attribute,"x") == 0)
            {
              flags=ParseGeometry(SvPV(ST(i),na),&geometry_info);
              x=geometry_info.rho;
              break;
            }
          ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
            attribute);
          break;
        }
        case 'y':
        case 'Y':
        {
          if (LocaleCompare(attribute,"y") == 0)
            {
              flags=ParseGeometry(SvPV(ST(i),na),&geometry_info);
              y=geometry_info.rho;
              break;
            }
          ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
            attribute);
          break;
        }
        default:
        {
          ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
            attribute);
          break;
        }
      }
    }
    draw_info->affine.sx=current.sx*affine.sx+current.ry*affine.rx;
    draw_info->affine.rx=current.rx*affine.sx+current.sy*affine.rx;
    draw_info->affine.ry=current.sx*affine.ry+current.ry*affine.sy;
    draw_info->affine.sy=current.rx*affine.ry+current.sy*affine.sy;
    draw_info->affine.tx=current.sx*affine.tx+current.ry*affine.ty+current.tx;
    draw_info->affine.ty=current.rx*affine.tx+current.sy*affine.ty+current.ty;
    if (draw_info->geometry == (char *) NULL)
      {
        draw_info->geometry=AcquireString((char *) NULL);
        (void) FormatLocaleString(draw_info->geometry,MagickPathExtent,
          "%.20g,%.20g",x,y);
      }
    status=GetTypeMetrics(image,draw_info,&metrics,exception);
    (void) CatchImageException(image);
    if (status == MagickFalse)
      PUSHs(&sv_undef);
    else
      {
        PUSHs(sv_2mortal(newSVnv(metrics.pixels_per_em.x)));
        PUSHs(sv_2mortal(newSVnv(metrics.pixels_per_em.y)));
        PUSHs(sv_2mortal(newSVnv(metrics.ascent)));
        PUSHs(sv_2mortal(newSVnv(metrics.descent)));
        PUSHs(sv_2mortal(newSVnv(metrics.width)));
        PUSHs(sv_2mortal(newSVnv(metrics.height)));
        PUSHs(sv_2mortal(newSVnv(metrics.max_advance)));
        PUSHs(sv_2mortal(newSVnv(metrics.bounds.x1)));
        PUSHs(sv_2mortal(newSVnv(metrics.bounds.y1)));
        PUSHs(sv_2mortal(newSVnv(metrics.bounds.x2)));
        PUSHs(sv_2mortal(newSVnv(metrics.bounds.y2)));
        PUSHs(sv_2mortal(newSVnv(metrics.origin.x)));
        PUSHs(sv_2mortal(newSVnv(metrics.origin.y)));
      }
    draw_info=DestroyDrawInfo(draw_info);

  PerlException:
    if (package_info != (struct PackageInfo *) NULL)
      DestroyPackageInfo(package_info);
    InheritPerlException(exception,perl_exception);
    exception=DestroyExceptionInfo(exception);
    SvREFCNT_dec(perl_exception);  /* can't return warning messages */
  }

#
###############################################################################
#                                                                             #
#                                                                             #
#                                                                             #
#   Q u e r y M u l t i l i n e F o n t M e t r i c s                         #
#                                                                             #
#                                                                             #
#                                                                             #
###############################################################################
#
#
void
QueryMultilineFontMetrics(ref,...)
  Image::Magick ref=NO_INIT
  ALIAS:
    querymultilinefontmetrics = 1
  PPCODE:
  {
    AffineMatrix
      affine,
      current;

    AV
      *av;

    char
      *attribute;

    double
      x,
      y;

    DrawInfo
      *draw_info;

    ExceptionInfo
      *exception;

    GeometryInfo
      geometry_info;

    Image
      *image;

    MagickBooleanType
      status;

    MagickStatusType
      flags;

    ssize_t
      i,
      type;

    struct PackageInfo
      *info,
      *package_info;

    SV
      *perl_exception,
      *reference;  /* reference is the SV* of ref=SvIV(reference) */

    TypeMetric
      metrics;

    PERL_UNUSED_VAR(ref);
    PERL_UNUSED_VAR(ix);
    exception=AcquireExceptionInfo();
    package_info=(struct PackageInfo *) NULL;
    perl_exception=newSVpv("",0);
    reference=SvRV(ST(0));
    av=(AV *) reference;
    info=GetPackageInfo(aTHX_ (void *) av,(struct PackageInfo *) NULL,
      exception);
    image=SetupList(aTHX_ reference,&info,(SV ***) NULL,exception);
    if (image == (Image *) NULL)
      {
        ThrowPerlException(exception,OptionError,"NoImagesDefined",
          PackageName);
        goto PerlException;
      }
    package_info=ClonePackageInfo(info,exception);
    draw_info=CloneDrawInfo(package_info->image_info,(DrawInfo *) NULL);
    CloneString(&draw_info->text,"");
    current=draw_info->affine;
    GetAffineMatrix(&affine);
    x=0.0;
    y=0.0;
    EXTEND(sp,7*items);
    for (i=2; i < items; i+=2)
    {
      attribute=(char *) SvPV(ST(i-1),na);
      switch (*attribute)
      {
        case 'A':
        case 'a':
        {
          if (LocaleCompare(attribute,"antialias") == 0)
            {
              type=ParseCommandOption(MagickBooleanOptions,MagickFalse,
                SvPV(ST(i),na));
              if (type < 0)
                {
                  ThrowPerlException(exception,OptionError,"UnrecognizedType",
                    SvPV(ST(i),na));
                  break;
                }
              draw_info->text_antialias=type != 0 ? MagickTrue : MagickFalse;
              break;
            }
          ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
            attribute);
          break;
        }
        case 'd':
        case 'D':
        {
          if (LocaleCompare(attribute,"density") == 0)
            {
              CloneString(&draw_info->density,SvPV(ST(i),na));
              break;
            }
          ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
            attribute);
          break;
        }
        case 'e':
        case 'E':
        {
          if (LocaleCompare(attribute,"encoding") == 0)
            {
              CloneString(&draw_info->encoding,SvPV(ST(i),na));
              break;
            }
          ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
            attribute);
          break;
        }
        case 'f':
        case 'F':
        {
          if (LocaleCompare(attribute,"family") == 0)
            {
              CloneString(&draw_info->family,SvPV(ST(i),na));
              break;
            }
          if (LocaleCompare(attribute,"fill") == 0)
            {
              if (info)
                (void) QueryColorCompliance(SvPV(ST(i),na),AllCompliance,
                  &draw_info->fill,exception);
              break;
            }
          if (LocaleCompare(attribute,"font") == 0)
            {
              CloneString(&draw_info->font,SvPV(ST(i),na));
              break;
            }
          ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
            attribute);
          break;
        }
        case 'g':
        case 'G':
        {
          if (LocaleCompare(attribute,"geometry") == 0)
            {
              CloneString(&draw_info->geometry,SvPV(ST(i),na));
              break;
            }
          if (LocaleCompare(attribute,"gravity") == 0)
            {
              draw_info->gravity=(GravityType) ParseCommandOption(
                MagickGravityOptions,MagickFalse,SvPV(ST(i),na));
              break;
            }
          ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
            attribute);
          break;
        }
        case 'p':
        case 'P':
        {
          if (LocaleCompare(attribute,"pointsize") == 0)
            {
              flags=ParseGeometry(SvPV(ST(i),na),&geometry_info);
              draw_info->pointsize=geometry_info.rho;
              break;
            }
          ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
            attribute);
          break;
        }
        case 'r':
        case 'R':
        {
          if (LocaleCompare(attribute,"rotate") == 0)
            {
              flags=ParseGeometry(SvPV(ST(i),na),&geometry_info);
              affine.rx=geometry_info.rho;
              affine.ry=geometry_info.sigma;
              if ((flags & SigmaValue) == 0)
                affine.ry=affine.rx;
              break;
            }
          ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
            attribute);
          break;
        }
        case 's':
        case 'S':
        {
          if (LocaleCompare(attribute,"scale") == 0)
            {
              flags=ParseGeometry(SvPV(ST(i),na),&geometry_info);
              affine.sx=geometry_info.rho;
              affine.sy=geometry_info.sigma;
              if ((flags & SigmaValue) == 0)
                affine.sy=affine.sx;
              break;
            }
          if (LocaleCompare(attribute,"skew") == 0)
            {
              double
                x_angle,
                y_angle;

              flags=ParseGeometry(SvPV(ST(i),na),&geometry_info);
              x_angle=geometry_info.rho;
              y_angle=geometry_info.sigma;
              if ((flags & SigmaValue) == 0)
                y_angle=x_angle;
              affine.ry=tan(DegreesToRadians(fmod(x_angle,360.0)));
              affine.rx=tan(DegreesToRadians(fmod(y_angle,360.0)));
              break;
            }
          if (LocaleCompare(attribute,"stroke") == 0)
            {
              if (info)
                (void) QueryColorCompliance(SvPV(ST(i),na),AllCompliance,
                  &draw_info->stroke,exception);
              break;
            }
          if (LocaleCompare(attribute,"style") == 0)
            {
              type=ParseCommandOption(MagickStyleOptions,MagickFalse,
                SvPV(ST(i),na));
              if (type < 0)
                {
                  ThrowPerlException(exception,OptionError,"UnrecognizedType",
                    SvPV(ST(i),na));
                  break;
                }
              draw_info->style=(StyleType) type;
              break;
            }
          ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
            attribute);
          break;
        }
        case 't':
        case 'T':
        {
          if (LocaleCompare(attribute,"text") == 0)
            {
              CloneString(&draw_info->text,SvPV(ST(i),na));
              break;
            }
          if (LocaleCompare(attribute,"translate") == 0)
            {
              flags=ParseGeometry(SvPV(ST(i),na),&geometry_info);
              affine.tx=geometry_info.rho;
              affine.ty=geometry_info.sigma;
              if ((flags & SigmaValue) == 0)
                affine.ty=affine.tx;
              break;
            }
          ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
            attribute);
          break;
        }
        case 'w':
        case 'W':
        {
          if (LocaleCompare(attribute,"weight") == 0)
            {
              flags=ParseGeometry(SvPV(ST(i),na),&geometry_info);
              draw_info->weight=(size_t) geometry_info.rho;
              break;
            }
          ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
            attribute);
          break;
        }
        case 'x':
        case 'X':
        {
          if (LocaleCompare(attribute,"x") == 0)
            {
              flags=ParseGeometry(SvPV(ST(i),na),&geometry_info);
              x=geometry_info.rho;
              break;
            }
          ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
            attribute);
          break;
        }
        case 'y':
        case 'Y':
        {
          if (LocaleCompare(attribute,"y") == 0)
            {
              flags=ParseGeometry(SvPV(ST(i),na),&geometry_info);
              y=geometry_info.rho;
              break;
            }
          ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
            attribute);
          break;
        }
        default:
        {
          ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
            attribute);
          break;
        }
      }
    }
    draw_info->affine.sx=current.sx*affine.sx+current.ry*affine.rx;
    draw_info->affine.rx=current.rx*affine.sx+current.sy*affine.rx;
    draw_info->affine.ry=current.sx*affine.ry+current.ry*affine.sy;
    draw_info->affine.sy=current.rx*affine.ry+current.sy*affine.sy;
    draw_info->affine.tx=current.sx*affine.tx+current.ry*affine.ty+current.tx;
    draw_info->affine.ty=current.rx*affine.tx+current.sy*affine.ty+current.ty;
    if (draw_info->geometry == (char *) NULL)
      {
        draw_info->geometry=AcquireString((char *) NULL);
        (void) FormatLocaleString(draw_info->geometry,MagickPathExtent,
          "%.20g,%.20g",x,y);
      }
    status=GetMultilineTypeMetrics(image,draw_info,&metrics,exception);
    (void) CatchException(exception);
    if (status == MagickFalse)
      PUSHs(&sv_undef);
    else
      {
        PUSHs(sv_2mortal(newSVnv(metrics.pixels_per_em.x)));
        PUSHs(sv_2mortal(newSVnv(metrics.pixels_per_em.y)));
        PUSHs(sv_2mortal(newSVnv(metrics.ascent)));
        PUSHs(sv_2mortal(newSVnv(metrics.descent)));
        PUSHs(sv_2mortal(newSVnv(metrics.width)));
        PUSHs(sv_2mortal(newSVnv(metrics.height)));
        PUSHs(sv_2mortal(newSVnv(metrics.max_advance)));
        PUSHs(sv_2mortal(newSVnv(metrics.bounds.x1)));
        PUSHs(sv_2mortal(newSVnv(metrics.bounds.y1)));
        PUSHs(sv_2mortal(newSVnv(metrics.bounds.x2)));
        PUSHs(sv_2mortal(newSVnv(metrics.bounds.y2)));
        PUSHs(sv_2mortal(newSVnv(metrics.origin.x)));
        PUSHs(sv_2mortal(newSVnv(metrics.origin.y)));
      }
    draw_info=DestroyDrawInfo(draw_info);

  PerlException:
    if (package_info != (struct PackageInfo *) NULL)
      DestroyPackageInfo(package_info);
    InheritPerlException(exception,perl_exception);
    exception=DestroyExceptionInfo(exception);
    SvREFCNT_dec(perl_exception);  /* can't return warning messages */
  }

#
###############################################################################
#                                                                             #
#                                                                             #
#                                                                             #
#   Q u e r y F o r m a t                                                     #
#                                                                             #
#                                                                             #
#                                                                             #
###############################################################################
#
#
void
QueryFormat(ref,...)
  Image::Magick ref=NO_INIT
  ALIAS:
    queryformat = 1
  PPCODE:
  {
    char
      *name;

    ExceptionInfo
      *exception;

    ssize_t
      i;

    SV
      *perl_exception;

    volatile const MagickInfo
      *magick_info;

    PERL_UNUSED_VAR(ref);
    PERL_UNUSED_VAR(ix);
    exception=AcquireExceptionInfo();
    perl_exception=newSVpv("",0);
    if (items == 1)
      {
        char
          format[MagickPathExtent];

        const MagickInfo
          **format_list;

        size_t
          types;

        format_list=GetMagickInfoList("*",&types,exception);
        EXTEND(sp,(ssize_t) types);
        for (i=0; i < (ssize_t) types; i++)
        {
          (void) CopyMagickString(format,format_list[i]->name,MagickPathExtent);
          LocaleLower(format);
          PUSHs(sv_2mortal(newSVpv(format,0)));
        }
        format_list=(const MagickInfo **)
          RelinquishMagickMemory((MagickInfo *) format_list);
        goto PerlException;
      }
    EXTEND(sp,8*items);
    for (i=1; i < items; i++)
    {
      name=(char *) SvPV(ST(i),na);
      magick_info=GetMagickInfo(name,exception);
      if (magick_info == (const MagickInfo *) NULL)
        {
          PUSHs(&sv_undef);
          continue;
        }
      if (magick_info->description == (char *) NULL)
        PUSHs(&sv_undef);
      else
        PUSHs(sv_2mortal(newSVpv(magick_info->description,0)));
      if (magick_info->magick_module == (char *) NULL)
        PUSHs(&sv_undef);
      else
        PUSHs(sv_2mortal(newSVpv(magick_info->magick_module,0)));
    }

  PerlException:
    InheritPerlException(exception,perl_exception);
    exception=DestroyExceptionInfo(exception);
    SvREFCNT_dec(perl_exception);
  }

#
###############################################################################
#                                                                             #
#                                                                             #
#                                                                             #
#   Q u e r y O p t i o n                                                     #
#                                                                             #
#                                                                             #
#                                                                             #
###############################################################################
#
#
void
QueryOption(ref,...)
  Image::Magick ref=NO_INIT
  ALIAS:
    queryoption = 1
  PPCODE:
  {
    char
      **options;

    ExceptionInfo
      *exception;

    ssize_t
      i,
      j,
      option;

    SV
      *perl_exception;

    PERL_UNUSED_VAR(ref);
    PERL_UNUSED_VAR(ix);
    exception=AcquireExceptionInfo();
    perl_exception=newSVpv("",0);
    EXTEND(sp,8*items);
    for (i=1; i < items; i++)
    {
      option=ParseCommandOption(MagickListOptions,MagickFalse,(char *)
        SvPV(ST(i),na));
      options=GetCommandOptions((CommandOption) option);
      if (options == (char **) NULL)
        PUSHs(&sv_undef);
      else
        {
          for (j=0; options[j] != (char *) NULL; j++)
            PUSHs(sv_2mortal(newSVpv(options[j],0)));
          options=DestroyStringList(options);
        }
    }

    InheritPerlException(exception,perl_exception);
    exception=DestroyExceptionInfo(exception);
    SvREFCNT_dec(perl_exception);
  }

#
###############################################################################
#                                                                             #
#                                                                             #
#                                                                             #
#   R e a d                                                                   #
#                                                                             #
#                                                                             #
#                                                                             #
###############################################################################
#
#
void
Read(ref,...)
  Image::Magick ref=NO_INIT
  ALIAS:
    ReadImage  = 1
    read       = 2
    readimage  = 3
  PPCODE:
  {
    AV
      *av;

    char
      **keep,
      **list,
      **p;

    ExceptionInfo
      *exception;

    HV
      *hv;

    Image
      *image;

    int
      n;

    MagickBooleanType
      status;

    ssize_t
      ac,
      i,
      number_images;

    STRLEN
      *length;

    struct PackageInfo
      *info,
      *package_info;

    SV
      *perl_exception,  /* Perl variable for storing messages */
      *reference,
      *rv,
      *sv;

    PERL_UNUSED_VAR(ref);
    PERL_UNUSED_VAR(ix);
    exception=AcquireExceptionInfo();
    perl_exception=newSVpv("",0);
    sv=NULL;
    package_info=(struct PackageInfo *) NULL;
    number_images=0;
    ac=(items < 2) ? 1 : items-1;
    list=(char **) AcquireQuantumMemory((size_t) ac+1UL,sizeof(*list));
    keep=list;
    length=(STRLEN *) NULL;
    if (list == (char **) NULL)
      {
        ThrowPerlException(exception,ResourceLimitError,
          "MemoryAllocationFailed",PackageName);
        goto PerlException;
      }
    length=(STRLEN *) AcquireQuantumMemory((size_t) ac+1UL,sizeof(*length));
    if (length == (STRLEN *) NULL)
      {
        ThrowPerlException(exception,ResourceLimitError,
          "MemoryAllocationFailed",PackageName);
        goto PerlException;
      }
    if (sv_isobject(ST(0)) == 0)
      {
        ThrowPerlException(exception,OptionError,"ReferenceIsNotMyType",
          PackageName);
        goto PerlException;
      }
    reference=SvRV(ST(0));
    hv=SvSTASH(reference);
    if (SvTYPE(reference) != SVt_PVAV)
      {
        ThrowPerlException(exception,OptionError,"ReferenceIsNotMyType",
          PackageName);
        goto PerlException;
      }
    av=(AV *) reference;
    info=GetPackageInfo(aTHX_ (void *) av,(struct PackageInfo *) NULL,
      exception);
    package_info=ClonePackageInfo(info,exception);
    n=1;
    if (items <= 1)
      *list=(char *) (*package_info->image_info->filename ?
        package_info->image_info->filename : "XC:black");
    else
      for (n=0, i=0; i < ac; i++)
      {
        list[n]=(char *) SvPV(ST(i+1),length[n]);
        if ((items >= 3) && strEQcase(list[n],"blob"))
          {
            void
              *blob;

            i++;
            blob=(void *) (SvPV(ST(i+1),length[n]));
            SetImageInfoBlob(package_info->image_info,blob,(size_t) length[n]);
          }
        if ((items >= 3) && strEQcase(list[n],"filename"))
          continue;
        if ((items >= 3) && strEQcase(list[n],"file"))
          {
            FILE
              *file;

            PerlIO
              *io_info;

            i++;
            io_info=IoIFP(sv_2io(ST(i+1)));
            if (io_info == (PerlIO *) NULL)
              {
                ThrowPerlException(exception,BlobError,"UnableToOpenFile",
                  PackageName);
                continue;
              }
            file=PerlIO_findFILE(io_info);
            if (file == (FILE *) NULL)
              {
                ThrowPerlException(exception,BlobError,"UnableToOpenFile",
                  PackageName);
                continue;
              }
            SetImageInfoFile(package_info->image_info,file);
          }
        if ((items >= 3) && strEQcase(list[n],"magick"))
          continue;
        n++;
      }
    list[n]=(char *) NULL;
    keep=list;
    status=ExpandFilenames(&n,&list);
    if (status == MagickFalse)
      {
        ThrowPerlException(exception,ResourceLimitError,
          "MemoryAllocationFailed",PackageName);
        goto PerlException;
      }
    number_images=0;
    for (i=0; i < n; i++)
    {
      if ((package_info->image_info->file == (FILE *) NULL) &&
          (package_info->image_info->blob == (void *) NULL))
        image=ReadImages(package_info->image_info,list[i],exception);
      else
        {
          image=ReadImages(package_info->image_info,
            package_info->image_info->filename,exception);
          if (image != (Image *) NULL)
            DisassociateImageStream(image);
        }
      if (image == (Image *) NULL)
        break;
      for ( ; image; image=image->next)
      {
        AddImageToRegistry(sv,image);
        rv=newRV(sv);
        av_push(av,sv_bless(rv,hv));
        SvREFCNT_dec(sv);
        number_images++;
      }
    }
    /*
      Free resources.
    */
    for (i=0; i < n; i++)
      if (list[i] != (char *) NULL)
        for (p=keep; list[i] != *p++; )
          if (*p == (char *) NULL)
            {
              list[i]=(char *) RelinquishMagickMemory(list[i]);
              break;
            }

  PerlException:
    if (package_info != (struct PackageInfo *) NULL)
      DestroyPackageInfo(package_info);
    if (list && (list != keep))
      list=(char **) RelinquishMagickMemory(list);
    if (keep)
      keep=(char **) RelinquishMagickMemory(keep);
    if (length)
      length=(STRLEN *) RelinquishMagickMemory(length);
    InheritPerlException(exception,perl_exception);
    exception=DestroyExceptionInfo(exception);
    sv_setiv(perl_exception,(IV) number_images);
    SvPOK_on(perl_exception);
    ST(0)=sv_2mortal(perl_exception);
    XSRETURN(1);
  }

#
###############################################################################
#                                                                             #
#                                                                             #
#                                                                             #
#   R e m o t e                                                               #
#                                                                             #
#                                                                             #
#                                                                             #
###############################################################################
#
#
void
Remote(ref,...)
  Image::Magick ref=NO_INIT
  ALIAS:
    RemoteCommand  = 1
    remote         = 2
    remoteCommand  = 3
  PPCODE:
  {
    AV
      *av;

    ExceptionInfo
      *exception;

    ssize_t
      i;

    SV
      *perl_exception,
      *reference;

    struct PackageInfo
      *info;

    PERL_UNUSED_VAR(ref);
    PERL_UNUSED_VAR(ix);
    exception=AcquireExceptionInfo();
    perl_exception=newSVpv("",0);
    reference=SvRV(ST(0));
    av=(AV *) reference;
    info=GetPackageInfo(aTHX_ (void *) av,(struct PackageInfo *) NULL,
      exception);
    for (i=1; i < items; i++)
      (void) RemoteDisplayCommand(info->image_info,(char *) NULL,(char *)
        SvPV(ST(i),na),exception);
    InheritPerlException(exception,perl_exception);
    exception=DestroyExceptionInfo(exception);
    SvREFCNT_dec(perl_exception);    /* throw away all errors */
  }

#
###############################################################################
#                                                                             #
#                                                                             #
#                                                                             #
#   S e t                                                                     #
#                                                                             #
#                                                                             #
#                                                                             #
###############################################################################
#
#
void
Set(ref,...)
  Image::Magick ref=NO_INIT
  ALIAS:
    SetAttributes  = 1
    SetAttribute   = 2
    set            = 3
    setattributes  = 4
    setattribute   = 5
  PPCODE:
  {
    ExceptionInfo
      *exception;

    Image
      *image;

    ssize_t
      i;

    struct PackageInfo
      *info;

    SV
      *perl_exception,
      *reference;  /* reference is the SV* of ref=SvIV(reference) */

    PERL_UNUSED_VAR(ref);
    PERL_UNUSED_VAR(ix);
    exception=AcquireExceptionInfo();
    perl_exception=newSVpv("",0);
    if (sv_isobject(ST(0)) == 0)
      {
        ThrowPerlException(exception,OptionError,"ReferenceIsNotMyType",
          PackageName);
        goto PerlException;
      }
    reference=SvRV(ST(0));
    image=SetupList(aTHX_ reference,&info,(SV ***) NULL,exception);
    if (items == 2)
      SetAttribute(aTHX_ info,image,"size",ST(1),exception);
    else
      for (i=2; i < items; i+=2)
        SetAttribute(aTHX_ info,image,SvPV(ST(i-1),na),ST(i),exception);

  PerlException:
    InheritPerlException(exception,perl_exception);
    exception=DestroyExceptionInfo(exception);
    sv_setiv(perl_exception,(IV) (SvCUR(perl_exception) != 0));
    SvPOK_on(perl_exception);
    ST(0)=sv_2mortal(perl_exception);
    XSRETURN(1);
  }

#
###############################################################################
#                                                                             #
#                                                                             #
#                                                                             #
#   S e t P i x e l                                                           #
#                                                                             #
#                                                                             #
#                                                                             #
###############################################################################
#
#
void
SetPixel(ref,...)
  Image::Magick ref=NO_INIT
  ALIAS:
    setpixel = 1
    setPixel = 2
  PPCODE:
  {
    AV
      *av;

    char
      *attribute;

    ChannelType
      channel,
      channel_mask;

    ExceptionInfo
      *exception;

    Image
      *image;

    MagickBooleanType
      normalize;

    Quantum
      *q;

    RectangleInfo
      region;

    ssize_t
      i,
      option;

    struct PackageInfo
      *info;

    SV
      *perl_exception,
      *reference;  /* reference is the SV* of ref=SvIV(reference) */

    PERL_UNUSED_VAR(ref);
    PERL_UNUSED_VAR(ix);
    exception=AcquireExceptionInfo();
    perl_exception=newSVpv("",0);
    reference=SvRV(ST(0));
    av=(AV *) reference;
    info=GetPackageInfo(aTHX_ (void *) av,(struct PackageInfo *) NULL,
      exception);
    image=SetupList(aTHX_ reference,&info,(SV ***) NULL,exception);
    if (image == (Image *) NULL)
      {
        ThrowPerlException(exception,OptionError,"NoImagesDefined",
          PackageName);
        goto PerlException;
      }
    av=(AV *) NULL;
    normalize=MagickTrue;
    region.x=0;
    region.y=0;
    region.width=image->columns;
    region.height=1;
    if (items == 1)
      (void) ParseAbsoluteGeometry(SvPV(ST(1),na),&region);
    channel=DefaultChannels;
    for (i=2; i < items; i+=2)
    {
      attribute=(char *) SvPV(ST(i-1),na);
      switch (*attribute)
      {
        case 'C':
        case 'c':
        {
          if (LocaleCompare(attribute,"channel") == 0)
            {
              ssize_t
                option;

              option=ParseChannelOption(SvPV(ST(i),na));
              if (option < 0)
                {
                  ThrowPerlException(exception,OptionError,"UnrecognizedType",
                    SvPV(ST(i),na));
                  return;
                }
              channel=(ChannelType) option;
              break;
            }
          if (LocaleCompare(attribute,"color") == 0)
            {
              if (SvTYPE(ST(i)) != SVt_RV)
                {
                  char
                    message[MagickPathExtent];

                  (void) FormatLocaleString(message,MagickPathExtent,
                    "invalid %.60s value",attribute);
                  ThrowPerlException(exception,OptionError,message,
                    SvPV(ST(i),na));
                }
              av=(AV *) SvRV(ST(i));
              break;
            }
          ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
            attribute);
          break;
        }
        case 'g':
        case 'G':
        {
          if (LocaleCompare(attribute,"geometry") == 0)
            {
              (void) ParseAbsoluteGeometry(SvPV(ST(i),na),&region);
              break;
            }
          ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
            attribute);
          break;
        }
        case 'N':
        case 'n':
        {
          if (LocaleCompare(attribute,"normalize") == 0)
            {
              option=ParseCommandOption(MagickBooleanOptions,MagickFalse,
                SvPV(ST(i),na));
              if (option < 0)
                {
                  ThrowPerlException(exception,OptionError,"UnrecognizedType",
                    SvPV(ST(i),na));
                  break;
                }
             normalize=option != 0 ? MagickTrue : MagickFalse;
             break;
            }
          ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
            attribute);
          break;
        }
        case 'x':
        case 'X':
        {
          if (LocaleCompare(attribute,"x") == 0)
            {
              region.x=SvIV(ST(i));
              break;
            }
          ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
            attribute);
          break;
        }
        case 'y':
        case 'Y':
        {
          if (LocaleCompare(attribute,"y") == 0)
            {
              region.y=SvIV(ST(i));
              break;
            }
          ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
            attribute);
          break;
        }
        default:
        {
          ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
            attribute);
          break;
        }
      }
    }
    (void) SetImageStorageClass(image,DirectClass,exception);
    channel_mask=SetImageChannelMask(image,channel);
    q=GetAuthenticPixels(image,region.x,region.y,1,1,exception);
    if ((q == (Quantum *) NULL) || (av == (AV *) NULL) ||
        (SvTYPE(av) != SVt_PVAV))
      PUSHs(&sv_undef);
    else
      {
        double
          scale;

        ssize_t
          i;

        i=0;
        scale=1.0;
        if (normalize != MagickFalse)
          scale=QuantumRange;
        if (((GetPixelRedTraits(image) & UpdatePixelTrait) != 0) &&
            (i <= av_len(av)))
          {
            SetPixelRed(image,ClampToQuantum(scale*SvNV(*(
              av_fetch(av,i,0)))),q);
            i++;
          }
        if (((GetPixelGreenTraits(image) & UpdatePixelTrait) != 0) &&
            (i <= av_len(av)))
          {
            SetPixelGreen(image,ClampToQuantum(scale*SvNV(*(
              av_fetch(av,i,0)))),q);
            i++;
          }
        if (((GetPixelBlueTraits(image) & UpdatePixelTrait) != 0) &&
            (i <= av_len(av)))
          {
            SetPixelBlue(image,ClampToQuantum(scale*SvNV(*(
              av_fetch(av,i,0)))),q);
            i++;
          }
        if ((((GetPixelBlackTraits(image) & UpdatePixelTrait) != 0) &&
            (image->colorspace == CMYKColorspace)) && (i <= av_len(av)))
          {
            SetPixelBlack(image,ClampToQuantum(scale*
              SvNV(*(av_fetch(av,i,0)))),q);
            i++;
          }
        if (((GetPixelAlphaTraits(image) & UpdatePixelTrait) != 0) &&
            (i <= av_len(av)))
          {
            SetPixelAlpha(image,ClampToQuantum(scale*
              SvNV(*(av_fetch(av,i,0)))),q);
            i++;
          }
        (void) SyncAuthenticPixels(image,exception);
      }
    (void) SetImageChannelMask(image,channel_mask);

  PerlException:
    InheritPerlException(exception,perl_exception);
    exception=DestroyExceptionInfo(exception);
    SvREFCNT_dec(perl_exception);
  }

#
###############################################################################
#                                                                             #
#                                                                             #
#                                                                             #
#   S e t P i x e l s                                                         #
#                                                                             #
#                                                                             #
#                                                                             #
###############################################################################
#
#
void
SetPixels(ref,...)
  Image::Magick ref=NO_INIT
  ALIAS:
    setpixels = 1
    setPixels = 2
  PPCODE:
  {
    AV
      *av;

    char
      *attribute;

    ChannelType
      channel,
      channel_mask;

    ExceptionInfo
      *exception;

    Image
      *image;

    Quantum
      *q;

    RectangleInfo
      region;

    ssize_t
      i;

    struct PackageInfo
      *info;

    SV
      *perl_exception,
      *reference;  /* reference is the SV* of ref=SvIV(reference) */

    PERL_UNUSED_VAR(ref);
    PERL_UNUSED_VAR(ix);
    exception=AcquireExceptionInfo();
    perl_exception=newSVpv("",0);
    reference=SvRV(ST(0));
    av=(AV *) reference;
    info=GetPackageInfo(aTHX_ (void *) av,(struct PackageInfo *) NULL,
      exception);
    image=SetupList(aTHX_ reference,&info,(SV ***) NULL,exception);
    if (image == (Image *) NULL)
      {
        ThrowPerlException(exception,OptionError,"NoImagesDefined",
          PackageName);
        goto PerlException;
      }
    av=(AV *) NULL;
    region.x=0;
    region.y=0;
    region.width=image->columns;
    region.height=1;
    if (items == 1)
      (void) ParseAbsoluteGeometry(SvPV(ST(1),na),&region);
    channel=DefaultChannels;
    for (i=2; i < items; i+=2)
    {
      attribute=(char *) SvPV(ST(i-1),na);
      switch (*attribute)
      {
        case 'C':
        case 'c':
        {
          if (LocaleCompare(attribute,"channel") == 0)
            {
              ssize_t
                option;

              option=ParseChannelOption(SvPV(ST(i),na));
              if (option < 0)
                {
                  ThrowPerlException(exception,OptionError,"UnrecognizedType",
                    SvPV(ST(i),na));
                  return;
                }
              channel=(ChannelType) option;
              break;
            }
          if (LocaleCompare(attribute,"color") == 0)
            {
              if (SvTYPE(ST(i)) != SVt_RV)
                {
                  char
                    message[MagickPathExtent];

                  (void) FormatLocaleString(message,MagickPathExtent,
                    "invalid %.60s value",attribute);
                  ThrowPerlException(exception,OptionError,message,
                    SvPV(ST(i),na));
                }
              av=(AV *) SvRV(ST(i));
              break;
            }
          ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
            attribute);
          break;
        }
        case 'g':
        case 'G':
        {
          if (LocaleCompare(attribute,"geometry") == 0)
            {
              (void) ParseAbsoluteGeometry(SvPV(ST(i),na),&region);
              break;
            }
          ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
            attribute);
          break;
        }
        case 'h':
        case 'H':
        {
          if (LocaleCompare(attribute,"height") == 0)
            {
              region.height=(size_t) SvIV(ST(i));
              break;
            }
          ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
            attribute);
          break;
        }
        case 'w':
        case 'W':
        {
          if (LocaleCompare(attribute,"width") == 0)
            {
              region.width=(size_t) SvIV(ST(i));
              break;
            }
          ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
            attribute);
          break;
        }
        case 'x':
        case 'X':
        {
          if (LocaleCompare(attribute,"x") == 0)
            {
              region.x=SvIV(ST(i));
              break;
            }
          ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
            attribute);
          break;
        }
        case 'y':
        case 'Y':
        {
          if (LocaleCompare(attribute,"y") == 0)
            {
              region.y=SvIV(ST(i));
              break;
            }
          ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
            attribute);
          break;
        }
        default:
        {
          ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
            attribute);
          break;
        }
      }
    }
    (void) SetImageStorageClass(image,DirectClass,exception);
    channel_mask=SetImageChannelMask(image,channel);
    q=GetAuthenticPixels(image,region.x,region.y,region.width,region.height,
      exception);
    if ((q == (Quantum *) NULL) || (av == (AV *) NULL) ||
        (SvTYPE(av) != SVt_PVAV))
      PUSHs(&sv_undef);
    else
      {
        double
          scale;

        ssize_t
          i,
          n,
          number_pixels;

        i=0;
        n=0;
        scale=(double) QuantumRange;
        number_pixels=(ssize_t) (region.width*region.height);
        while ((n < number_pixels) && (i < av_len(av)))
        {
          if (((GetPixelRedTraits(image) & UpdatePixelTrait) != 0) &&
              (i <= av_len(av)))
            {
              SetPixelRed(image,ClampToQuantum(scale*SvNV(*(
                av_fetch(av,i,0)))),q);
              i++;
            }
          if (((GetPixelGreenTraits(image) & UpdatePixelTrait) != 0) &&
              (i <= av_len(av)))
            {
              SetPixelGreen(image,ClampToQuantum(scale*SvNV(*(
                av_fetch(av,i,0)))),q);
              i++;
            }
          if (((GetPixelBlueTraits(image) & UpdatePixelTrait) != 0) &&
              (i <= av_len(av)))
            {
              SetPixelBlue(image,ClampToQuantum(scale*SvNV(*(
                av_fetch(av,i,0)))),q);
              i++;
            }
          if ((((GetPixelBlackTraits(image) & UpdatePixelTrait) != 0) &&
              (image->colorspace == CMYKColorspace)) && (i <= av_len(av)))
            {
             SetPixelBlack(image,ClampToQuantum(scale*
                SvNV(*(av_fetch(av,i,0)))),q);
              i++;
            }
          if (((GetPixelAlphaTraits(image) & UpdatePixelTrait) != 0) &&
              (i <= av_len(av)))
            {
              SetPixelAlpha(image,ClampToQuantum(scale*
                SvNV(*(av_fetch(av,i,0)))),q);
              i++;
            }
         	n++;
         	q+=image->number_channels;
        }
        (void) SyncAuthenticPixels(image,exception);
      }
    (void) SetImageChannelMask(image,channel_mask);

  PerlException:
    InheritPerlException(exception,perl_exception);
    exception=DestroyExceptionInfo(exception);
    SvREFCNT_dec(perl_exception);
  }

#
###############################################################################
#                                                                             #
#                                                                             #
#                                                                             #
#   S m u s h                                                                 #
#                                                                             #
#                                                                             #
#                                                                             #
###############################################################################
#
#
void
Smush(ref,...)
  Image::Magick ref=NO_INIT
  ALIAS:
    SmushImage  = 1
    smush       = 2
    smushimage  = 3
  PPCODE:
  {
    AV
      *av;

    char
      *attribute;

    ExceptionInfo
      *exception;

    HV
      *hv;

    Image
      *image;

    ssize_t
      i,
      offset,
      stack;

    struct PackageInfo
      *info;

    SV
      *av_reference,
      *perl_exception,
      *reference,
      *rv,
      *sv;

    PERL_UNUSED_VAR(ref);
    PERL_UNUSED_VAR(ix);
    exception=AcquireExceptionInfo();
    perl_exception=newSVpv("",0);
    sv=NULL;
    attribute=NULL;
    av=NULL;
    if (sv_isobject(ST(0)) == 0)
      {
        ThrowPerlException(exception,OptionError,"ReferenceIsNotMyType",
          PackageName);
        goto PerlException;
      }
    reference=SvRV(ST(0));
    hv=SvSTASH(reference);
    av=newAV();
    av_reference=sv_2mortal(sv_bless(newRV((SV *) av),hv));
    SvREFCNT_dec(av);
    image=SetupList(aTHX_ reference,&info,(SV ***) NULL,exception);
    if (image == (Image *) NULL)
      {
        ThrowPerlException(exception,OptionError,"NoImagesDefined",
          PackageName);
        goto PerlException;
      }
    info=GetPackageInfo(aTHX_ (void *) av,info,exception);
    /*
      Get options.
    */
    offset=0;
    stack=MagickTrue;
    for (i=2; i < items; i+=2)
    {
      attribute=(char *) SvPV(ST(i-1),na);
      switch (*attribute)
      {
        case 'O':
        case 'o':
        {
          if (LocaleCompare(attribute,"offset") == 0)
            {
              offset=(ssize_t) StringToLong((char *) SvPV(ST(1),na));
              break;
            }
          ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
            attribute);
          break;
        }
        case 'S':
        case 's':
        {
          if (LocaleCompare(attribute,"stack") == 0)
            {
              stack=ParseCommandOption(MagickBooleanOptions,MagickFalse,
                SvPV(ST(i),na));
              if (stack < 0)
                {
                  ThrowPerlException(exception,OptionError,"UnrecognizedType",
                    SvPV(ST(i),na));
                  return;
                }
              break;
            }
          ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
            attribute);
          break;
        }
        default:
        {
          ThrowPerlException(exception,OptionError,"UnrecognizedAttribute",
            attribute);
          break;
        }
      }
    }
    image=SmushImages(image,stack != 0 ? MagickTrue : MagickFalse,offset,
      exception);
    if (image == (Image *) NULL)
      goto PerlException;
    for ( ; image; image=image->next)
    {
      AddImageToRegistry(sv,image);
      rv=newRV(sv);
      av_push(av,sv_bless(rv,hv));
      SvREFCNT_dec(sv);
    }
    exception=DestroyExceptionInfo(exception);
    ST(0)=av_reference;
    SvREFCNT_dec(perl_exception);
    XSRETURN(1);

  PerlException:
    InheritPerlException(exception,perl_exception);
    exception=DestroyExceptionInfo(exception);
    sv_setiv(perl_exception,(IV) SvCUR(perl_exception) != 0);
    SvPOK_on(perl_exception);
    ST(0)=sv_2mortal(perl_exception);
    XSRETURN(1);
  }

#
###############################################################################
#                                                                             #
#                                                                             #
#                                                                             #
#   S t a t i s t i c s                                                       #
#                                                                             #
#                                                                             #
#                                                                             #
###############################################################################
#
#
void
Statistics(ref,...)
  Image::Magick ref=NO_INIT
  ALIAS:
    StatisticsImage = 1
    statistics      = 2
    statisticsimage = 3
  PPCODE:
  {
#define ChannelStatistics(channel) \
{ \
  (void) FormatLocaleString(message,MagickPathExtent,"%.20g", \
    (double) channel_statistics[channel].depth); \
  PUSHs(sv_2mortal(newSVpv(message,0))); \
  (void) FormatLocaleString(message,MagickPathExtent,"%.20g", \
    channel_statistics[channel].minima/QuantumRange); \
  PUSHs(sv_2mortal(newSVpv(message,0))); \
  (void) FormatLocaleString(message,MagickPathExtent,"%.20g", \
    channel_statistics[channel].maxima/QuantumRange); \
  PUSHs(sv_2mortal(newSVpv(message,0))); \
  (void) FormatLocaleString(message,MagickPathExtent,"%.20g", \
    channel_statistics[channel].mean/QuantumRange); \
  PUSHs(sv_2mortal(newSVpv(message,0))); \
  (void) FormatLocaleString(message,MagickPathExtent,"%.20g", \
    channel_statistics[channel].standard_deviation/QuantumRange); \
  PUSHs(sv_2mortal(newSVpv(message,0))); \
  (void) FormatLocaleString(message,MagickPathExtent,"%.20g", \
    channel_statistics[channel].kurtosis); \
  PUSHs(sv_2mortal(newSVpv(message,0))); \
  (void) FormatLocaleString(message,MagickPathExtent,"%.20g", \
    channel_statistics[channel].skewness); \
  PUSHs(sv_2mortal(newSVpv(message,0))); \
  (void) FormatLocaleString(message,MagickPathExtent,"%.20g", \
    channel_statistics[channel].entropy); \
  PUSHs(sv_2mortal(newSVpv(message,0))); \
}

    AV
      *av;

    char
      message[MagickPathExtent];

    ChannelStatistics
      *channel_statistics;

    ExceptionInfo
      *exception;

    Image
      *image;

    ssize_t
      count;

    struct PackageInfo
      *info;

    SV
      *perl_exception,
      *reference;

    PERL_UNUSED_VAR(ref);
    PERL_UNUSED_VAR(ix);
    exception=AcquireExceptionInfo();
    perl_exception=newSVpv("",0);
    av=NULL;
    if (sv_isobject(ST(0)) == 0)
      {
        ThrowPerlException(exception,OptionError,"ReferenceIsNotMyType",
          PackageName);
        goto PerlException;
      }
    reference=SvRV(ST(0));
    av=newAV();
    SvREFCNT_dec(av);
    image=SetupList(aTHX_ reference,&info,(SV ***) NULL,exception);
    if (image == (Image *) NULL)
      {
        ThrowPerlException(exception,OptionError,"NoImagesDefined",
          PackageName);
        goto PerlException;
      }
    count=0;
    for ( ; image; image=image->next)
    {
      ssize_t
        i;

      channel_statistics=GetImageStatistics(image,exception);
      if (channel_statistics == (ChannelStatistics *) NULL)
        continue;
      count++;
      for (i=0; i < (ssize_t) GetPixelChannels(image); i++)
      {
        PixelChannel channel=GetPixelChannelChannel(image,i);
        PixelTrait traits=GetPixelChannelTraits(image,channel);
        if (traits == UndefinedPixelTrait)
          continue;
        EXTEND(sp,8*(i+1)*count);
        ChannelStatistics(channel);
      }
      EXTEND(sp,8*(i+1)*count);
      ChannelStatistics(CompositePixelChannel);
      channel_statistics=(ChannelStatistics *)
        RelinquishMagickMemory(channel_statistics);
    }

  PerlException:
    InheritPerlException(exception,perl_exception);
    exception=DestroyExceptionInfo(exception);
    SvREFCNT_dec(perl_exception);
  }

#
###############################################################################
#                                                                             #
#                                                                             #
#                                                                             #
#   S y n c A u t h e n t i c P i x e l s                                     #
#                                                                             #
#                                                                             #
#                                                                             #
###############################################################################
#
#
void
SyncAuthenticPixels(ref,...)
  Image::Magick ref = NO_INIT
  ALIAS:
    Syncauthenticpixels = 1
    SyncImagePixels = 2
    syncimagepixels = 3
  CODE:
  {
    ExceptionInfo
      *exception;

    Image
      *image;

    MagickBooleanType
      status;

    struct PackageInfo
      *info;

    SV
      *perl_exception,
      *reference;

    PERL_UNUSED_VAR(ref);
    PERL_UNUSED_VAR(ix);
    exception=AcquireExceptionInfo();
    perl_exception=newSVpv("",0);
    if (sv_isobject(ST(0)) == 0)
      {
        ThrowPerlException(exception,OptionError,"ReferenceIsNotMyType",
          PackageName);
        goto PerlException;
      }

    reference=SvRV(ST(0));
    image=SetupList(aTHX_ reference,&info,(SV ***) NULL,exception);
    if (image == (Image *) NULL)
      {
        ThrowPerlException(exception,OptionError,"NoImagesDefined",
          PackageName);
        goto PerlException;
      }

    status=SyncAuthenticPixels(image,exception);
    if (status != MagickFalse)
      return;

  PerlException:
    InheritPerlException(exception,perl_exception);
    exception=DestroyExceptionInfo(exception);
    SvREFCNT_dec(perl_exception);  /* throw away all errors */
  }

#
###############################################################################
#                                                                             #
#                                                                             #
#                                                                             #
#   W r i t e                                                                 #
#                                                                             #
#                                                                             #
#                                                                             #
###############################################################################
#
#
void
Write(ref,...)
  Image::Magick ref=NO_INIT
  ALIAS:
    WriteImage    = 1
    write         = 2
    writeimage    = 3
  PPCODE:
  {
    char
      filename[MagickPathExtent];

    ExceptionInfo
      *exception;

    Image
      *image,
      *next;

    ssize_t
      i,
      number_images,
      scene;

    struct PackageInfo
      *info,
      *package_info;

    SV
      *perl_exception,
      *reference;

    PERL_UNUSED_VAR(ref);
    PERL_UNUSED_VAR(ix);
    exception=AcquireExceptionInfo();
    perl_exception=newSVpv("",0);
    number_images=0;
    package_info=(struct PackageInfo *) NULL;
    if (sv_isobject(ST(0)) == 0)
      {
        ThrowPerlException(exception,OptionError,"ReferenceIsNotMyType",
          PackageName);
        goto PerlException;
      }
    reference=SvRV(ST(0));
    image=SetupList(aTHX_ reference,&info,(SV ***) NULL,exception);
    if (image == (Image *) NULL)
      {
        ThrowPerlException(exception,OptionError,"NoImagesDefined",
          PackageName);
        goto PerlException;
      }
    scene=0;
    for (next=image; next; next=next->next)
      next->scene=(size_t) scene++;
    package_info=ClonePackageInfo(info,exception);
    if (items == 2)
      SetAttribute(aTHX_ package_info,NULL,"filename",ST(1),exception);
    else
      if (items > 2)
        for (i=2; i < items; i+=2)
          SetAttribute(aTHX_ package_info,image,SvPV(ST(i-1),na),ST(i),
            exception);
    (void) CopyMagickString(filename,package_info->image_info->filename,
      MagickPathExtent);
    for (next=image; next; next=next->next)
      (void) CopyMagickString(next->filename,filename,MagickPathExtent);
    *package_info->image_info->magick='\0';
    SetImageInfo(package_info->image_info,(unsigned int)
      GetImageListLength(image),exception);
    for (next=image; next; next=next->next)
    {
      (void) WriteImage(package_info->image_info,next,exception);
      number_images++;
      if (package_info->image_info->adjoin)
        break;
    }

  PerlException:
    if (package_info != (struct PackageInfo *) NULL)
      DestroyPackageInfo(package_info);
    InheritPerlException(exception,perl_exception);
    exception=DestroyExceptionInfo(exception);
    sv_setiv(perl_exception,(IV) number_images);
    SvPOK_on(perl_exception);
    ST(0)=sv_2mortal(perl_exception);
    XSRETURN(1);
  }
