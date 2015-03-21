// Copyright 2015 Google Inc. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

library saga.main;

import 'dart:html';

import 'package:observe/observe.dart';

import 'package:saga/src/parser.dart' as parser;
import 'package:saga/src/flow.dart' as flow;
import 'package:saga/src/ui/ir_pane/ir_pane.dart' as ir_pane;
import 'package:ui_utils/graph_layout.dart' as graph_layout;
import 'package:saga/src/ui/code_pane.dart' as code_pane;
import 'package:saga/src/ui/tooltip.dart';
import 'package:ui_utils/delayed_reaction.dart';


import 'package:liquid/liquid.dart';
import 'package:liquid/vdom.dart' as v;

timeAndReport(action, name) {
  final stopwatch = new Stopwatch()..start();
  final result = action();
  print("${name} took ${stopwatch.elapsedMilliseconds} ms.");
  return result;
}

displayGraph(Element pane, blocks, ref) {
  final stopwatch = new Stopwatch()..start();
  graph_layout.display(pane, blocks, (label, blockId) {
    label.onMouseOver.listen((event) => ref.show(event.target, blockId));
    label.onMouseOut.listen((_) => ref.hide());
  });
  print("graph_layout took ${stopwatch.elapsedMilliseconds}");
}

render(code, {keepScroll: false}) {
  timeAndReport(() {
    app.flowData = flow.build(code);
  }, "flow analysis");
}


class BlockTooltip extends Tooltip {
  final flowData;
  
  final _delayed = new DelayedReaction(delay: const Duration(milliseconds: 100));
  
  int id = maxId++;
  static int maxId = 0;
  
  toString() => "BlockTooltip($id)";
  
  BlockTooltip(this.flowData);

  show(el, id) {
    print("${this}.show(${el}, ${id})");
    _delayed.schedule(() {
      final block = flowData.blocks[id];
      target = el;
      isVisible = true;
      content = () => v.pre()([
        code_pane.vBlock(block: block),
        v.text('\n'),
        ir_pane.vBlock(block: block)
      ]);
    });
  }

  hide() {
    _delayed.cancel();
    isVisible = false;
  }
}


final vGraphPane = v.componentFactory(GraphPaneComponent);
class GraphPaneComponent extends Component {
  @property() var flowData;
  
  var graphPane;
  var tooltip;
  
  build() =>
    v.root()([
      graphPane = v.div(classes: const ['graph-pane']),
      (tooltip = new BlockTooltip(flowData)).build()
    ]);
  
  update() async {
    await writeDOM();
    print(tooltip);
    displayGraph(graphPane.ref, flowData.blocks, tooltip);
  }
}

class SagaApp extends Observable {
  @observable var flowData; 
}

class SagaAppComponent extends Component {
  var app;
  
  init() {
    app.changes.listen((_) => invalidate());
  }
  
  build() =>
    v.root(classes: const ["saga-app"])(app.flowData == null ? const [] : [
      code_pane.vCodePane(flowData: app.flowData),
      vGraphPane(flowData: app.flowData),
      ir_pane.vIrPane(flowData: app.flowData)
    ]);
}

final app = new SagaApp();

main() {
  injectComponent(new SagaAppComponent()..app = app, document.querySelector("body"));

  HttpRequest.getString("code.asm").then((text) {
    final code = timeAndReport(() => parser.parse(text), "parsing");
    render(code);

    code.changes.listen((_) => render(code, keepScroll: true));
  });
}