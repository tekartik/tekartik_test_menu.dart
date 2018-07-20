import 'dart:async';
import 'package:tekartik_test_menu/src/test_menu/test_menu_manager.dart';

abstract class WithParent {
  TestMenu get parent;
  set parent(TestMenu parent);
}

class _WithParentMixin implements WithParent {
  TestMenu parent;
}

abstract class TestItem implements Runnable, WithParent {
  String get cmd;
  String get name;
  factory TestItem.fn(String name, TestItemFn fn, {String cmd, bool solo}) {
    return new RunnableTestItem(name, fn, cmd: cmd, solo: solo);
  }
  factory TestItem.menu(TestMenu menu) {
    return new MenuTestItem(menu);
  }
}

typedef R TestItemFn<R>();

abstract class _BaseTestItem {
  String name;
  String get cmd;
  _BaseTestItem(this.name);

  @override
  String toString() {
    return name;
  }
}

abstract class Runnable {
  run();
}

class _RunnableMixin implements Runnable {
  TestItemFn fn;
  run() {
    return fn();
  }
}

class MenuEnter extends Object with _RunnableMixin, _WithParentMixin {
  MenuEnter(TestItemFn fn) {
    this.fn = fn;
  }

  @override
  String toString() {
    return 'enter';
  }
}

class MenuLeave extends Object with _RunnableMixin, _WithParentMixin {
  MenuLeave(TestItemFn fn) {
    this.fn = fn;
  }

  @override
  String toString() {
    return 'leave';
  }
}

class RunnableTestItem extends _BaseTestItem
    with _RunnableMixin, _WithParentMixin
    implements TestItem {
  String cmd;
  bool solo;
  RunnableTestItem(String name, TestItemFn fn, {this.cmd, this.solo})
      : super(name) {
    this.fn = fn;
  }
}

class MenuTestItem extends _BaseTestItem
    with _WithParentMixin
    implements TestItem {
  TestMenu menu;
  String get cmd => menu.cmd;
  MenuTestItem(this.menu) : super(null) {
    name = menu.name;
  }

  Future run() async {
    await testMenuManager.pushMenu(menu);
  }

  @override
  String toString() {
    return 'menu ${super.toString()}';
  }
}

class RootTestMenu extends TestMenu {
  RootTestMenu() : super(null);
}

class TestMenu extends Object with _WithParentMixin {
  String cmd;
  String name;
  List<TestItem> _items = [];
  List<TestItem> get items => _items;
  int get length => _items.length;
  TestMenu(this.name, {this.cmd});
  List<MenuEnter> _enters = [];
  List<MenuLeave> _leaves = [];

  Iterable<MenuEnter> get enters => _enters;
  Iterable<MenuLeave> get leaves => _leaves;
  void add(String name, TestItemFn fn) => addItem(new TestItem.fn(name, fn));
  fixParent(WithParent child) {
    child.parent = this;
  }

  void addEnter(MenuEnter menuEnter) {
    fixParent(menuEnter);
    _enters.add(menuEnter);
  }

  void addLeave(MenuLeave menuLeave) {
    fixParent(menuLeave);
    _leaves.add(menuLeave);
  }

  void addMenu(TestMenu menu) {
    fixParent(menu);
    addItem(new TestItem.menu(menu));
  }

  void addItem(TestItem item) {
    fixParent(item);
    _items.add(item);
  }

  void addAll(List<TestItem> items) => items.forEach((TestItem item) {
        addItem(item);
      });
  TestItem operator [](int index) => _items[index];
  TestItem byCmd(String cmd) {
    for (TestItem item in _items) {
      if (item.cmd == cmd) {
        return item;
      }
    }
    int value = int.tryParse(cmd) ?? -1;

    if (value != null && (value >= 0 && value < length)) {
      return _items[value];
    }
    return null;
  }

  @override
  String toString() {
    return "tm'$name'";
  }

  int indexOfItem(TestItem item) {
    return _items.indexOf(item);
  }

  int indexOfMenu(TestMenu menu) {
    for (int i = 0; i < _items.length; i++) {
      TestItem item = _items[i];
      if (item is MenuTestItem) {
        if (item.menu == menu) {
          return i;
        }
      }
    }
    return -1;
  }
}