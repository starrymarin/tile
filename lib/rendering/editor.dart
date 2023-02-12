import 'package:bamboo/bamboo.dart';
import 'package:bamboo/rendering/cursor.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

class Editor extends StatefulWidget {
  const Editor({super.key, required Document child}) : document = child;

  final Document document;

  static EditorState of(BuildContext context) {
    _EditorScope scope =
        context.dependOnInheritedWidgetOfExactType<_EditorScope>()!;
    return scope._editorKey.currentContext
        ?.findAncestorStateOfType<EditorState>() as EditorState;
  }

  static RenderEditor renderObject(BuildContext context) {
    _EditorScope scope =
        context.dependOnInheritedWidgetOfExactType<_EditorScope>()!;
    return scope._editorKey.currentContext?.findRenderObject() as RenderEditor;
  }

  @override
  State<StatefulWidget> createState() => EditorState();
}

class EditorState extends State<Editor>
    with TickerProviderStateMixin<Editor>, EditorStateFloatingCursorMixin {
  final GlobalKey _editorKey = GlobalKey();

  RenderEditor get renderEditor =>
      _editorKey.currentContext?.findRenderObject() as RenderEditor;

  @override
  Widget build(BuildContext context) {
    return _EditorScope(
      editorKey: _editorKey,
      child: _Editor(
        key: _editorKey,
        child: widget.document,
      ),
    );
  }
}

class _EditorScope extends InheritedWidget {
  const _EditorScope({required GlobalKey editorKey, required super.child})
      : _editorKey = editorKey;

  final GlobalKey _editorKey;

  @override
  bool updateShouldNotify(covariant _EditorScope oldWidget) {
    return _editorKey != oldWidget._editorKey;
  }
}

class _Editor extends MultiChildRenderObjectWidget {
  _Editor({
    required GlobalKey super.key,
    required Document child,
  }) : super(children: [_DocumentProxy(child: child)]);

  @override
  RenderObject createRenderObject(BuildContext context) {
    return RenderEditor(
      bambooTheme: BambooTheme.of(context),
      devicePixelRatio: MediaQuery.of(context).devicePixelRatio,
    );
  }

  @override
  void updateRenderObject(
      BuildContext context, covariant RenderEditor renderObject) {
    renderObject
      ..bambooTheme = BambooTheme.of(context)
      ..devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
  }
}

class _DocumentProxy extends SingleChildRenderObjectWidget {
  const _DocumentProxy({required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderDocumentProxy();
  }
}

/// 这个类的目的是用来判断[RenderEditor]中的哪一个child是用来渲染document的
class _RenderDocumentProxy extends RenderProxyBox {}

class EditorParentData extends ContainerBoxParentData<RenderBox> {}

mixin _RenderEditorWithDocumentProxyMixin on RenderObject
    implements RenderObjectWithChildMixin<_RenderDocumentProxy> {
  _RenderDocumentProxy? _child;

  @override
  _RenderDocumentProxy? get child => _child;

  @override
  set child(_RenderDocumentProxy? value) {
    _child = value;
  }
}

///
/// 本质上这是一个RenderProxyBox，代理的是Document的render，通过Document的render来
/// layout,paint等等。
///
/// 之所以需要多个child，是因为floatingCursor等render是独立的，这样在光标变动时，仅需
/// 标记RenderFloatingCursor needsPaint即可，而不需要标记整个RenderEditor
///
class RenderEditor extends RenderBox
    with
        RelayoutWhenSystemFontsChangeMixin,
        ContainerRenderObjectMixin<RenderBox, EditorParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, EditorParentData>,
        _RenderEditorWithDocumentProxyMixin,
        RenderProxyBoxMixin<_RenderDocumentProxy>,
        RenderEditorFloatingCursorMixin {
  RenderEditor({
    required BambooTheme bambooTheme,
    required double devicePixelRatio,
  })  : _bambooTheme = bambooTheme,
        _devicePixelRatio = devicePixelRatio {
    renderEditorFloatingCursor = RenderEditorFloatingCursor(
      bambooTheme: _bambooTheme,
      devicePixelRatio: _devicePixelRatio,
    );
  }

  BambooTheme _bambooTheme;

  set bambooTheme(BambooTheme value) {
    if (_bambooTheme == value) {
      return;
    }
    _bambooTheme = value;
    renderEditorFloatingCursor.bambooTheme = _bambooTheme;
    markNeedsPaint();
  }

  double _devicePixelRatio;

  set devicePixelRatio(double value) {
    if (_devicePixelRatio == value) {
      return;
    }
    _devicePixelRatio = value;
    renderEditorFloatingCursor.devicePixelRatio = _devicePixelRatio;
    markNeedsLayout();
  }

  @override
  void insert(RenderBox child, {RenderBox? after}) {
    super.insert(child, after: after);
    if (child is _RenderDocumentProxy) {
      this.child = child;
    }
  }

  @override
  void setupParentData(covariant RenderObject child) {
    if (child.parentData is! EditorParentData) {
      child.parentData = EditorParentData();
    }
  }
}

@protected
class RenderEditorCustomPaint extends RenderBox {
  @override
  RenderEditor? get parent => super.parent as RenderEditor?;

  @override
  bool get isRepaintBoundary => true;

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;
}
