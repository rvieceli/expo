#include "EXWebGLRenderer.h"
#include "EXGLContext.h"
#include "EXGLContextManager.h"
#include "EXJsiUtils.h"
#include "EXWebGLMethods.h"
#include "jsi/jsi.h"

namespace expo {
namespace gl_cpp {

constexpr const char *EXGLContextsMapPropertyName = "__EXGLContexts";

void installConstants(jsi::Runtime &runtime, jsi::Object &gl);
void installWebGLMethods(jsi::Runtime &runtime, jsi::Object &gl);
void installWebGL2Methods(jsi::Runtime &runtime, jsi::Object &gl);

void createWebGLRenderer(jsi::Runtime &runtime, EXGLContext *ctx, initGlesContext viewport) {
  ensurePrototypes(runtime);
  jsi::Object gl = ctx->supportsWebGL2
    ? createWebGLObject(
          runtime, EXWebGLClass::WebGL2RenderingContext, {static_cast<double>(ctx->ctxId)})
          .asObject(runtime)
    : createWebGLObject(
          runtime, EXWebGLClass::WebGLRenderingContext, {static_cast<double>(ctx->ctxId)})
          .asObject(runtime);

  gl.setProperty(runtime, "drawingBufferWidth", viewport.viewportWidth);
  gl.setProperty(runtime, "drawingBufferHeight", viewport.viewportHeight);
  gl.setProperty(runtime, "supportsWebGL2", ctx->supportsWebGL2);
  gl.setProperty(runtime, "exglCtxId", static_cast<double>(ctx->ctxId));

  // Legacy case for older SDKs in Expo Go
  bool legacyJs = !runtime.global().getProperty(runtime, "__EXGLConstructorReady").isBool();
  if (legacyJs) {
    installConstants(runtime, gl);
    ctx->supportsWebGL2 ? installWebGL2Methods(runtime, gl) : installWebGLMethods(runtime, gl);
  }

  jsi::Value jsContextMap = runtime.global().getProperty(runtime, EXGLContextsMapPropertyName);
  auto global = runtime.global();
  if (jsContextMap.isNull() || jsContextMap.isUndefined()) {
    global.setProperty(runtime, EXGLContextsMapPropertyName, jsi::Object(runtime));
  }
  global.getProperty(runtime, EXGLContextsMapPropertyName)
      .asObject(runtime)
      .setProperty(runtime, jsi::PropNameID::forUtf8(runtime, std::to_string(ctx->ctxId)), gl);
}

// For some reason call to Function::callAsConstructor returns null,
// so we had to create this object using Object.create(class.prototype).
// This approach works correctlly with instnceof in Hermes, but not in JSC.
//
// Issue might be caused the fact that constructor is a host function
// and it behaves like an arrow function.
jsi::Value createWebGLObject(
    jsi::Runtime &runtime,
    EXWebGLClass webglClass,
    std::initializer_list<jsi::Value> &&args) {
  jsi::Function constructor =
      runtime.global()
          .getProperty(runtime, jsi::PropNameID::forUtf8(runtime, getConstructorName(webglClass)))
          .asObject(runtime)
          .asFunction(runtime);
  jsi::Object objectClass = runtime.global().getPropertyAsObject(runtime, "Object");
  jsi::Function createMethod = objectClass.getPropertyAsFunction(runtime, "create");
  jsi::Object webglObject =
      createMethod
          .callWithThis(runtime, objectClass, {constructor.getProperty(runtime, "prototype")})
          .asObject(runtime);
  jsi::Value id = args.size() > 0 ? jsi::Value(runtime, *args.begin()) : jsi::Value::undefined();
  constructor.callWithThis(runtime, webglObject, { jsi::Value(runtime, id) });
  // Legacy case for older SDKs in Expo Go
  if (!webglObject.getProperty(runtime, "id").isNumber()) {
    webglObject.setProperty(runtime, "id", id);
  }
  return webglObject;
}

std::string getConstructorName(EXWebGLClass value) {
  switch (value) {
    case EXWebGLClass::WebGLRenderingContext:
      return "WebGLRenderingContext";
    case EXWebGLClass::WebGL2RenderingContext:
      return "WebGL2RenderingContext";
    case EXWebGLClass::WebGLObject:
      return "WebGLObject";
    case EXWebGLClass::WebGLBuffer:
      return "WebGLBuffer";
    case EXWebGLClass::WebGLFramebuffer:
      return "WebGLFramebuffer";
    case EXWebGLClass::WebGLProgram:
      return "WebGLProgram";
    case EXWebGLClass::WebGLRenderbuffer:
      return "WebGLRenderbuffer";
    case EXWebGLClass::WebGLShader:
      return "WebGLShader";
    case EXWebGLClass::WebGLTexture:
      return "WebGLTexture";
    case EXWebGLClass::WebGLUniformLocation:
      return "WebGLUniformLocation";
    case EXWebGLClass::WebGLActiveInfo:
      return "WebGLActiveInfo";
    case EXWebGLClass::WebGLShaderPrecisionFormat:
      return "WebGLShaderPrecisionFormat";
    case EXWebGLClass::WebGLQuery:
      return "WebGLQuery";
    case EXWebGLClass::WebGLSampler:
      return "WebGLSampler";
    case EXWebGLClass::WebGLSync:
      return "WebGLSync";
    case EXWebGLClass::WebGLTransformFeedback:
      return "WebGLTransformFeedback";
    case EXWebGLClass::WebGLVertexArrayObject:
      return "WebGLVertexArrayObject";
  }
}

void attachClass(
    jsi::Runtime &runtime,
    EXWebGLClass webglClass,
    std::function<void(EXWebGLClass webglClass)> installPrototypes) {
  jsi::PropNameID name = jsi::PropNameID::forUtf8(runtime, getConstructorName(webglClass));
  auto constructor = jsi::Function::createFromHostFunction(
      runtime,
      name,
      0,
      [](jsi::Runtime &runtime, const jsi::Value &jsThis, const jsi::Value *jsArgv, size_t argc) {
        if (argc > 0) {
          jsThis.asObject(runtime).setProperty(runtime, "id", jsArgv[0]);
        }
        return jsi::Value::undefined();
      });
  runtime.global().setProperty(runtime, name, constructor);
  installPrototypes(webglClass);
}

// https://developer.mozilla.org/en-US/docs/Learn/JavaScript/Objects/Inheritance#setting_teachers_prototype_and_constructor_reference
//
// Below implementation is equivalent of `class WebGLBuffer extends WebGLObject {}`
// where baseClass=global.WebGLObject and derivedProp="WebGLBuffer"
//
// WebGLBuffer.prototype = Object.create(WebGLObject.prototype);
// Object.defineProperty(WebGLBuffer.prototype, 'constructor', {
//   value: WebGLBuffer,
//   enumerable: false,
//   configurable: true,
//   writable: true });
void jsClassExtend(jsi::Runtime &runtime, jsi::Object &baseClass, jsi::PropNameID derivedProp) {
  jsi::PropNameID prototype = jsi::PropNameID::forUtf8(runtime, "prototype");
  jsi::Object objectClass = runtime.global().getPropertyAsObject(runtime, "Object");
  jsi::Function createMethod = objectClass.getPropertyAsFunction(runtime, "create");
  jsi::Function definePropertyMethod = objectClass.getPropertyAsFunction(runtime, "defineProperty");
  jsi::Object derivedClass = runtime.global().getProperty(runtime, derivedProp).asObject(runtime);

  // WebGLBuffer.prototype = Object.create(WebGLObject.prototype);
  derivedClass.setProperty(
      runtime,
      prototype,
      createMethod.callWithThis(runtime, objectClass, {baseClass.getProperty(runtime, prototype)}));

  jsi::Object propertyOptions(runtime);
  propertyOptions.setProperty(runtime, "value", derivedClass);
  propertyOptions.setProperty(runtime, "enumerable", false);
  propertyOptions.setProperty(runtime, "configurable", true);
  propertyOptions.setProperty(runtime, "writable", true);

  // Object.defineProperty ...
  definePropertyMethod.callWithThis(
      runtime,
      objectClass,
      {
          derivedClass.getProperty(runtime, prototype),
          jsi::String::createFromUtf8(runtime, "constructor"),
          std::move(propertyOptions),
      });
}

void ensurePrototypes(jsi::Runtime &runtime) {
  if (runtime.global().hasProperty(runtime, "WebGLRenderingContext")) {
    return;
  }
  runtime.global().setProperty(runtime, "__EXGLConstructorReady", true);
  attachClass(runtime, EXWebGLClass::WebGLRenderingContext, [&runtime](EXWebGLClass classEnum) {
    auto objectClass = runtime.global().getPropertyAsObject(runtime, "Object");
    jsClassExtend(
        runtime, objectClass, jsi::PropNameID::forUtf8(runtime, getConstructorName(classEnum)));

    auto prototype =
        runtime.global()
            .getProperty(runtime, jsi::PropNameID::forUtf8(runtime, getConstructorName(classEnum)))
            .asObject(runtime)
            .getPropertyAsObject(runtime, "prototype");
    installConstants(runtime, prototype);
    installWebGLMethods(runtime, prototype);
  });

  attachClass(runtime, EXWebGLClass::WebGL2RenderingContext, [&runtime](EXWebGLClass classEnum) {
    auto objectClass = runtime.global().getPropertyAsObject(runtime, "Object");
    jsClassExtend(
        runtime, objectClass, jsi::PropNameID::forUtf8(runtime, getConstructorName(classEnum)));
    auto prototype =
        runtime.global()
            .getProperty(runtime, jsi::PropNameID::forUtf8(runtime, getConstructorName(classEnum)))
            .asObject(runtime)
            .getPropertyAsObject(runtime, "prototype");
    installConstants(runtime, prototype);
    installWebGL2Methods(runtime, prototype);
  });

  auto inheritFromJsObject = [&runtime](EXWebGLClass classEnum) {
    auto objectClass = runtime.global().getPropertyAsObject(runtime, "Object");
    jsClassExtend(
        runtime, objectClass, jsi::PropNameID::forUtf8(runtime, getConstructorName(classEnum)));
  };
  attachClass(runtime, EXWebGLClass::WebGLObject, inheritFromJsObject);

  jsi::Object webglObjectClass =
      runtime.global()
          .getProperty(
              runtime,
              jsi::PropNameID::forUtf8(runtime, getConstructorName(EXWebGLClass::WebGLObject)))
          .asObject(runtime);
  auto inheritFromWebGLObject = [&runtime, &webglObjectClass](EXWebGLClass classEnum) {
    jsClassExtend(
        runtime,
        webglObjectClass,
        jsi::PropNameID::forUtf8(runtime, getConstructorName(classEnum)));
  };

  attachClass(runtime, EXWebGLClass::WebGLBuffer, inheritFromWebGLObject);
  attachClass(runtime, EXWebGLClass::WebGLFramebuffer, inheritFromWebGLObject);
  attachClass(runtime, EXWebGLClass::WebGLProgram, inheritFromWebGLObject);
  attachClass(runtime, EXWebGLClass::WebGLRenderbuffer, inheritFromWebGLObject);
  attachClass(runtime, EXWebGLClass::WebGLShader, inheritFromWebGLObject);
  attachClass(runtime, EXWebGLClass::WebGLTexture, inheritFromWebGLObject);
  attachClass(runtime, EXWebGLClass::WebGLUniformLocation, inheritFromJsObject);
  attachClass(runtime, EXWebGLClass::WebGLActiveInfo, inheritFromJsObject);
  attachClass(runtime, EXWebGLClass::WebGLShaderPrecisionFormat, inheritFromJsObject);
  attachClass(runtime, EXWebGLClass::WebGLQuery, inheritFromWebGLObject);
  attachClass(runtime, EXWebGLClass::WebGLSampler, inheritFromWebGLObject);
  attachClass(runtime, EXWebGLClass::WebGLSync, inheritFromWebGLObject);
  attachClass(runtime, EXWebGLClass::WebGLTransformFeedback, inheritFromWebGLObject);
  attachClass(runtime, EXWebGLClass::WebGLVertexArrayObject, inheritFromWebGLObject);
}

void installConstants(jsi::Runtime &runtime, jsi::Object &gl) {
#define GL_CONSTANT(name) gl.setProperty(runtime, #name, static_cast<double>(GL_##name));
#include "EXGLConstants.def"
#undef GL_CONSTANT
}

void installWebGLMethods(jsi::Runtime &runtime, jsi::Object &gl) {
#define NATIVE_METHOD(name) setFunctionOnObject(runtime, gl, #name, method::glNativeMethod_##name);

#define NATIVE_WEBGL2_METHOD(name) ;
#include "EXWebGLMethods.def"
#undef NATIVE_WEBGL2_METHOD
#undef NATIVE_METHOD
}

void installWebGL2Methods(jsi::Runtime &runtime, jsi::Object &gl) {
#define CREATE_METHOD(name) setFunctionOnObject(runtime, gl, #name, method::glNativeMethod_##name);

#define NATIVE_METHOD(name) CREATE_METHOD(name)
#define NATIVE_WEBGL2_METHOD(name) CREATE_METHOD(name)
#include "EXWebGLMethods.def"
#undef NATIVE_WEBGL2_METHOD
#undef NATIVE_METHOD
#undef CREATE_METHOD
}

} // namespace gl_cpp
} // namespace expo
