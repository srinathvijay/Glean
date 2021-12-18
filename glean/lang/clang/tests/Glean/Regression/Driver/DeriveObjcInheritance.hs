{-
  Copyright (c) Facebook, Inc. and its affiliates.
  All rights reserved.

  This source code is licensed under the BSD-style license found in the
  LICENSE file in the root directory of this source tree.
-}

module Glean.Regression.Driver.DeriveObjcInheritance(main) where

import Derive.Lib
import Glean.Clang.Test.DerivePass

main :: IO ()
main = testDeriver [DeriveGeneric "cxx1.ObjcContainerInheritance"]
