import 'package:tekartik_common_utils/common_utils_import.dart';
import 'package:tekartik_test_menu/src/test_menu/test_menu.dart';
import 'package:tekartik_test_menu/test_menu.dart';
import 'package:tekartik_test_menu/test_menu_presenter.dart';
import 'package:stack_trace/stack_trace.dart';

//import 'src/common.dart';
bool get debugTestMenuManager => TestMenuManager.debug.on;

TestMenuManager _testMenuManager;

TestMenuManager get testMenuManager {
  if (_testMenuManager == null) {
    if (testMenuPresenter != null) {
      _testMenuManager = new TestMenuManager(testMenuPresenter);
    } else {
      throw ('Cannot tell whether you\'re running from io or browser. Please include the proper header');
    }
  }
  return _testMenuManager;
}

set testMenuManager(TestMenuManager testMenuManager) =>
    _testMenuManager = testMenuManager;

initTestMenuManager() {}

@deprecated
void showTestMenu(TestMenu menu) {
  initTestMenuManager();
  testMenuManager.push(menu);
}

Future pushMenu(TestMenu menu) async {
  initTestMenuManager();
  return await testMenuManager.pushMenu(menu);
}

Future popMenu() async {
  return await testMenuManager.popMenu();
}

Future processMenu(TestMenu menu) async {
  return await testMenuManager.processMenu(menu);
}

/*
class TestMenuManagerDefault extends TestMenuManager {

  TestMenuPresenter presenter;

  TestMenuManagerDefault(this.presenter);

  @override
  Future presentMenu(TestMenu menu) async {
    await testMenuPresenter.presentMenu(menu);
  }

  @override
  Future<String> prompt(Object message) {
    return testMenuPresenter.prompt(message);
  }

  Future runItem(TestItem item) async {
    await testMenuPresenter.preProcessItem(item);
    await super.runItem(item);
  }
}

*/
class TestMenuRunner {
  final TestMenu menu;
  final TestMenuRunner parent;

  bool entered = false;

  TestMenuRunner(this.parent, this.menu);

  Future enter() async {
    if (!entered) {
      entered = true;
      await parent?.enter();
      for (var enter_ in menu.enters) {
        await _run(enter_);
      }
    }
  }

  Future _run(Runnable runnable) async {
    if (debugTestMenuManager) {
      write("[run] running '$runnable'");
    }
    try {
      await runnable.run();
    } catch (e, st) {
      testMenuPresenter.write("ERROR CAUGHT $e ${Trace.format(st)}");
      rethrow;
    } finally {
      if (debugTestMenuManager) {
        write("[run] done '$runnable'");
      }
    }
  }

  Future leave() async {
    if (!entered) {
      entered = false;
      for (var leave in menu.leaves) {
        await _run(leave);
      }
    }
  }
}

class TestMenuManager {
  final TestMenuPresenter presenter;
  SynchronizedLock lock = new SynchronizedLock();
  static final DevFlag debug = new DevFlag("TestMenuManager");
  //TestMenu displayedMenu;
  Map<TestMenu, TestMenuRunner> menuRunners = {};

  TestMenuRunner get activeMenuRunner {
    if (stackMenus.length > 0) {
      return stackMenus.last;
    }
    return null;
  }

  TestMenu get activeMenu => activeMenuRunner?.menu;

  List<TestMenuRunner> stackMenus = new List();

  static List<String> initCommandsFromHash(String hash) {
    if (debugTestMenuManager) {
      print("hash: $hash");
    }
    int firstHash = hash.indexOf('#');
    if (firstHash == 0) {
      int nextHash = hash.indexOf('#', 1);
      if (nextHash < 0) {
        hash = hash.substring(1);
      } else {
        hash = hash.substring(firstHash + 1, nextHash);
      }
    } else if (firstHash > 0) {
      hash = hash.substring(0, firstHash);
    }
    List<String> commands = hash.split('_');
    if (debugTestMenuManager) {
      print("hash: $hash commands: $commands");
    }
    return commands;
  }

  TestMenuManager(this.presenter) {
    // unique?
    testMenuManager = this;
  }

  /*
  TestMenu _startMenu;

  void setStartMenu(TestMenu menu) {
    _startMenu = menu;
  }
  */

  Future pushMenu(TestMenu menu) async {
    if (_push(menu)) {
      await presenter.presentMenu(menu);

      //eventually process init items
      await menuRunners[menu]?.enter();

      await processMenu(menu);
    }
    return true;
  }

  @deprecated
  bool push(TestMenu menu) {
    if (_push(menu)) {
      presenter.presentMenu(menu);
    }
    return true;
  }

  bool stackContainsMenu(TestMenu menu) {
    return menuRunners[menu] != null;
  }

  bool _push(TestMenu menu) {
    if (stackContainsMenu(menu)) {
      return false;
    }
    TestMenuRunner runner = new TestMenuRunner(activeMenuRunner, menu);
    _pushMenuRunner(runner);
    menuRunners[menu] = runner;
    stackMenus.add(runner);
    return true;
  }

  bool _pushMenuRunner(TestMenuRunner menuRunner) {
    //if (stackMenus.contains(menuRunner)) {
    //  return false;
    //}
    menuRunners[menuRunner.menu] = menuRunner;
    stackMenus.add(menuRunner);
    return true;
  }

  Future<bool> popMenu([int count = 1]) async {
    TestMenuRunner activeMenuRunner = this.activeMenuRunner;
    bool poped = _pop(count);
    if (poped && activeMenuRunner != null) {
      await activeMenuRunner.leave();
      await presenter.presentMenu(this.activeMenuRunner.menu);
    }
    return poped;
  }

  /*
  @deprecated
  bool pop([int count = 1]) {
    if (_pop(count)) {
      presentMenu(activeMenu);
      return true;
    }
    return false;
  }
  */

  bool _pop([int count = 1]) {
    if (stackMenus.length > 1) {
      stackMenus.removeRange(stackMenus.length - count, stackMenus.length);
      return true;
    }
    return false;
  }

  int get activeDepth {
    return stackMenus.length - 1;
  }

  Future _run(Runnable runnable) async {
    if (debugTestMenuManager) {
      print("[run] running '$runnable'");
    }
    try {
      await runnable.run();
    } catch (e, st) {
      write("ERROR CAUGHT $e ${Trace.format(st)}");
      rethrow;
    } finally {
      if (debugTestMenuManager) {
        print("[run] done '$runnable'");
      }
    }
  }

  Future runItem(TestItem item) async {
    await enterMenu(item.parent);
    await _run(item);
  }

  Future enterMenu(TestMenu menu) async {}

  /**
   * Commands executed on startup
   */
  List<String> initCommands;

  void stop() {
    // _inCommandSubscription.cancel();
  }

  // Process a command line
  Future processLine(String line) async {
    TestMenu menu = activeMenu;
    //devPrint('Line: $line / Menu $menu');

    int value = int.parse(line, onError: (String textValue) {
      if (textValue == '-') {
        print('pop');

        return -1;
      }
      //         if (textValue == '.') {
      //           _displayMenu(menu);
      //           return null;
      //         }
      //         print('errorValue: $textValue');
      //         print('- exit');
      //         print('. display menu again');
    });
    if (value == -1) {
      if (!await popMenu()) {
        stop();
      }
    } else {
      if (value != null) {
        if (value >= 0 && value < menu.length) {
          return runItem(menu[value]);
          // }
          //        if (value == -1) {
          //          break;
          //        };
        }
      }
    }
  }

  bool _initCommandHandled = false;

  // Process current menu
  // Run initial commands if needed first
  Future processMenu(TestMenu menu) async {
    if (!_initCommandHandled) {
      _initCommandHandled = true;

      List<String> initCommands = this.initCommands;
      if (initCommands != null) {
        for (String initCommand in initCommands) {
          await processLine(initCommand);
        }
      }
    }
  }

  /*
  @deprecated
  void onProcessMenu(TestMenu menu) {
    if (!_initCommandHandled) {
      _initCommandHandled = true;

      List<String> initCommands = this.initCommands;
      Future _processLine(int index) {
        if (initCommands != null && index < initCommands.length) {
          return processLine(initCommands[index]).then((_) {
            return _processLine(index + 1);
          });
        }
        return new Future.value();
      }

      _processLine(0);
    }
  }
  */

  //void onProcessItem(TestItem item) {}
}
