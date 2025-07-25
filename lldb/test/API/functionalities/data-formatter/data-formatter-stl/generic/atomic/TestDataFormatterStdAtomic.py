"""
Test lldb data formatter subsystem.
"""

import re
import lldb
from lldbsuite.test.decorators import *
from lldbsuite.test.lldbtest import *
from lldbsuite.test import lldbutil


class StdAtomicTestCase(TestBase):
    def get_variable(self, name):
        var = self.frame().FindVariable(name)
        var.SetPreferDynamicValue(lldb.eDynamicCanRunTarget)
        var.SetPreferSyntheticValue(True)
        return var

    def do_test(self):
        """Test that std::atomic is correctly printed by LLDB"""
        self.runCmd("file " + self.getBuildArtifact("a.out"), CURRENT_EXECUTABLE_SET)

        bkpt = self.target().FindBreakpointByID(
            lldbutil.run_break_set_by_source_regexp(
                self, "Set break point at this line."
            )
        )

        self.runCmd("run", RUN_SUCCEEDED)

        # The stop reason of the thread should be breakpoint.
        self.expect(
            "thread list",
            STOPPED_DUE_TO_BREAKPOINT,
            substrs=["stopped", "stop reason = breakpoint"],
        )

        s_atomic = self.get_variable("s")
        i_atomic = self.get_variable("i")

        if self.TraceOn():
            print(s_atomic)
        if self.TraceOn():
            print(i_atomic)

        # Extract the content of the std::atomic wrappers.
        self.assertEqual(s_atomic.GetNumChildren(), 1)
        s = s_atomic.GetChildAtIndex(0)
        self.assertEqual(i_atomic.GetNumChildren(), 1)
        i = i_atomic.GetChildAtIndex(0)

        self.assertEqual(i.GetValueAsUnsigned(0), 5, "i == 5")
        self.assertEqual(s.GetNumChildren(), 2, "s has two children")
        self.assertEqual(s.GetChildAtIndex(0).GetValueAsUnsigned(0), 1, "s.x == 1")
        self.assertEqual(s.GetChildAtIndex(1).GetValueAsUnsigned(0), 2, "s.y == 2")

        # Try printing the child that points to its own parent object.
        # This should just treat the atomic pointer as a normal pointer.
        self.expect("frame var p.child", substrs=["Value = 0x"])
        self.expect("frame var p", substrs=["parent = {", "Value = 0x", "}"])
        self.expect(
            "frame var p.child.parent", substrs=["p.child.parent = {\n  Value = 0x"]
        )

    @skipIf(compiler=["gcc"])
    @add_test_categories(["libc++"])
    def test_libcxx(self):
        self.build(dictionary={"USE_LIBCPP": 1})
        self.do_test()

    @add_test_categories(["msvcstl"])
    def test_msvcstl(self):
        # No flags, because the "msvcstl" category checks that the MSVC STL is used by default.
        self.build()
        self.do_test()
