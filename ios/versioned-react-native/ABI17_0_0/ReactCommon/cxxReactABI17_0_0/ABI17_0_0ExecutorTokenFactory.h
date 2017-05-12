// Copyright 2004-present Facebook. All Rights Reserved.

#pragma once

#include <cxxReactABI17_0_0/ABI17_0_0Executor.h>
#include <cxxReactABI17_0_0/ABI17_0_0ExecutorToken.h>

namespace facebook {
namespace ReactABI17_0_0 {

/**
 * Class that knows how to create the platform-specific implementation
 * of ExecutorToken.
 */
class ExecutorTokenFactory {
public:
  virtual ~ExecutorTokenFactory() {}

  /**
   * Creates a new ExecutorToken.
   */
  virtual ExecutorToken createExecutorToken() const = 0;
};

} }
