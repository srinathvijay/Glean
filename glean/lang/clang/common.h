/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#pragma once

#include <glean/cpp/glean.h>

namespace facebook {
namespace glean {
namespace clangx {

using namespace facebook::glean::cpp;

// Sort of 'inherit' all operator() of passed types
template <typename... Ts>
struct overload : Ts... {
  using Ts::operator()...;
};
// deduction guide
template <typename... Ts>
overload(Ts...) -> overload<Ts...>;

}
}
}
