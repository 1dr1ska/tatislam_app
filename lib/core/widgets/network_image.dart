import 'package:cached_network_image_platform_interface'
    '/cached_network_image_platform_interface.dart'
    show ImageRenderMethodForWeb;
import 'package:flutter/foundation.dart' show kIsWeb;

/// Image render method used for every network image in the app.
///
/// On the web the `cached_network_image` default is
/// [ImageRenderMethodForWeb.HtmlImage], which decodes every image through a
/// separate HTML `<img>` element. When the user navigates between sections the
/// grid is rebuilt and those elements are disposed mid-decode — the browser
/// aborts the in-flight fetch, and freshly created `<img>` elements for the
/// same URL then fail (first a black/partially decoded tile, later the
/// broken-image fallback). Fetching the bytes with
/// [ImageRenderMethodForWeb.HttpGet] and decoding them directly avoids the
/// fragile HTML image element lifecycle entirely, so photos survive
/// navigation on the web.
///
/// On mobile/desktop the IO loader ignores the enum, so this only affects web.
ImageRenderMethodForWeb get appWebImageRenderMethod => kIsWeb
    ? ImageRenderMethodForWeb.HttpGet
    : ImageRenderMethodForWeb.HtmlImage;