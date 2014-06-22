window.onerror = function() {
  if (parent.onerror) {
    return parent.onerror.apply(parent, arguments);
  }
};

window.Mocha = Object.create(parent.Mocha);
window.mocha = Object.create(parent.mocha);

// In order to isolate top-level before/beforeEach hooks,
// the specs in each iframe are wrapped in an anonymous suite.
mocha.suite = Mocha.Suite.create(mocha.suite);

mocha.suite.path = document.documentElement.getAttribute("data-path");

// Override mocha.ui so that the pre-require event is emitted
// with the iframe's `window` reference, rather than the parent's.
mocha.ui = function (name) {
  this._ui = Mocha.interfaces[name];
  if (!this._ui) throw new Error('invalid interface "' + name + '"');
  this._ui = this._ui(this.suite);
  this.suite.emit('pre-require', window, null, this);
  return this;
};

mocha.ui('bdd');

console.info(mocha);

//Show only the current iframe.
mocha.suite.beforeAll(function () {
  var iframes = parent.$(".iframe-spec");
  console.warn(iframes);
  $.each(iframes, function(index, iframe){
    if (iframe.contentWindow == window){
      $(iframe).css("display", "block")
      $(iframe).attr("id", "current-iframe")
    } else {
      $(iframe).removeAttr("style")
      $(iframe).removeAttr("id")
    }
  });
});

// proxy the Ecl to the parent
window.Ecl = parent.Ecl;

// var eclMethods = [];

console.info("suites", mocha.suite.suites);

mocha.suite.beforeEach(function() {
  console.info("beforeEach", this.test, this.test.title)
  // get the test id here
  // automatically iterate through all of the Ecl methods
  // binding them to the tests id here
});

var emit = Mocha.Runner.prototype.emit
Mocha.Runner.prototype.emit = function() {
  console.log("Child Runner Proto emit", window, this, arguments);
  var args = [].slice.apply(arguments);

  switch(args[0]){
    case "suite":
      // dont return here, just log something special since its the root suite
      if(args[1].root) return;

      // proxy the Ecl methods here with the suite's title + id
      console.log("suite title is", args[1].title);
      break;
    case "test":
      // proxy all of the Ecl methods here with the test's title + id
      console.log("test title is:", args[1].title)
      break;

  };

  emit.apply(this, arguments);
};

var expect = chai.expect,
    should = chai.should(),
    assert = chai.assert;
