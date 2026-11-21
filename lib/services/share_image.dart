import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../core/theme.dart';

/// Lays out, paints and encodes [child] as a PNG without putting it on
/// screen: a private render tree whose root is a [RepaintBoundary], captured
/// with `toImage`. The result is [size] × [pixelRatio] pixels.
Future<Uint8List> renderPng(
  Widget child, {
  required Size size,
  required double pixelRatio,
  ui.FlutterView? view,
}) async {
  final boundary = RenderRepaintBoundary();
  final renderView = RenderView(
    view: view ?? WidgetsBinding.instance.platformDispatcher.views.first,
    configuration: ViewConfiguration(
      logicalConstraints: BoxConstraints.tight(size),
      physicalConstraints: BoxConstraints.tight(size * pixelRatio),
      devicePixelRatio: pixelRatio,
    ),
    child: RenderPositionedBox(child: boundary),
  );
  final pipeline = PipelineOwner()..rootNode = renderView;
  renderView.prepareInitialFrame();
  final buildOwner = BuildOwner(focusManager: FocusManager());
  final root = RenderObjectToWidgetAdapter<RenderBox>(
    container: boundary,
    child: MediaQuery(
      data: MediaQueryData(size: size, devicePixelRatio: pixelRatio),
      child: Theme(
        data: buildTheme(),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: DefaultTextStyle(style: LSText.body(14), child: child),
        ),
      ),
    ),
  ).attachToRenderTree(buildOwner);
  try {
    buildOwner
      ..buildScope(root)
      ..finalizeTree();
    pipeline
      ..flushLayout()
      ..flushCompositingBits()
      ..flushPaint();
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data!.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  } finally {
    // The private tree only holds stateless widgets; drop it.
    renderView.child = null;
    pipeline.rootNode = null;
    buildOwner.focusManager.dispose();
  }
}
