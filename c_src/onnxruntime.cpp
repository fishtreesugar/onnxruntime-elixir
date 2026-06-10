#include <fine.hpp>
#include <onnxruntime_cxx_api.h>

#include <algorithm>
#include <cstring>
#include <limits>
#include <numeric>
#include <sstream>

namespace atoms {
auto cpu = fine::Atom("cpu");
auto f = fine::Atom("f");
auto bf = fine::Atom("bf");
auto s = fine::Atom("s");
auto u = fine::Atom("u");
auto pred = fine::Atom("pred");
} // namespace atoms

using DTypeTerm = std::tuple<fine::Atom, uint64_t>;
using ShapeTerm = std::vector<std::optional<int64_t>>;
using IOTerm = std::tuple<std::string, std::string, ShapeTerm>;

static Ort::Env &ort_env() {
  static Ort::Env env(ORT_LOGGING_LEVEL_WARNING, "onnxruntime_elixir");
  return env;
}

static size_t element_size(ONNXTensorElementDataType type) {
  switch (type) {
  case ONNX_TENSOR_ELEMENT_DATA_TYPE_BOOL:
  case ONNX_TENSOR_ELEMENT_DATA_TYPE_UINT8:
  case ONNX_TENSOR_ELEMENT_DATA_TYPE_INT8:
    return 1;
  case ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT16:
  case ONNX_TENSOR_ELEMENT_DATA_TYPE_BFLOAT16:
  case ONNX_TENSOR_ELEMENT_DATA_TYPE_UINT16:
  case ONNX_TENSOR_ELEMENT_DATA_TYPE_INT16:
    return 2;
  case ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT:
  case ONNX_TENSOR_ELEMENT_DATA_TYPE_UINT32:
  case ONNX_TENSOR_ELEMENT_DATA_TYPE_INT32:
    return 4;
  case ONNX_TENSOR_ELEMENT_DATA_TYPE_DOUBLE:
  case ONNX_TENSOR_ELEMENT_DATA_TYPE_UINT64:
  case ONNX_TENSOR_ELEMENT_DATA_TYPE_INT64:
    return 8;
  default:
    throw std::invalid_argument("unsupported ONNX tensor element type");
  }
}

static ONNXTensorElementDataType decode_dtype(const DTypeTerm &term) {
  auto [kind, bits] = term;
  auto name = kind.to_string();

  if (name == "f" && bits == 16)
    return ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT16;
  if (name == "f" && bits == 32)
    return ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT;
  if (name == "f" && bits == 64)
    return ONNX_TENSOR_ELEMENT_DATA_TYPE_DOUBLE;
  if (name == "bf" && bits == 16)
    return ONNX_TENSOR_ELEMENT_DATA_TYPE_BFLOAT16;
  if (name == "s" && bits == 8)
    return ONNX_TENSOR_ELEMENT_DATA_TYPE_INT8;
  if (name == "s" && bits == 16)
    return ONNX_TENSOR_ELEMENT_DATA_TYPE_INT16;
  if (name == "s" && bits == 32)
    return ONNX_TENSOR_ELEMENT_DATA_TYPE_INT32;
  if (name == "s" && bits == 64)
    return ONNX_TENSOR_ELEMENT_DATA_TYPE_INT64;
  if (name == "u" && bits == 8)
    return ONNX_TENSOR_ELEMENT_DATA_TYPE_UINT8;
  if (name == "u" && bits == 16)
    return ONNX_TENSOR_ELEMENT_DATA_TYPE_UINT16;
  if (name == "u" && bits == 32)
    return ONNX_TENSOR_ELEMENT_DATA_TYPE_UINT32;
  if (name == "u" && bits == 64)
    return ONNX_TENSOR_ELEMENT_DATA_TYPE_UINT64;
  if (name == "pred" && bits == 8)
    return ONNX_TENSOR_ELEMENT_DATA_TYPE_BOOL;

  throw std::invalid_argument("unsupported Nx tensor type");
}

static DTypeTerm encode_dtype(ONNXTensorElementDataType type) {
  switch (type) {
  case ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT16:
    return {atoms::f, 16};
  case ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT:
    return {atoms::f, 32};
  case ONNX_TENSOR_ELEMENT_DATA_TYPE_DOUBLE:
    return {atoms::f, 64};
  case ONNX_TENSOR_ELEMENT_DATA_TYPE_BFLOAT16:
    return {atoms::bf, 16};
  case ONNX_TENSOR_ELEMENT_DATA_TYPE_INT8:
    return {atoms::s, 8};
  case ONNX_TENSOR_ELEMENT_DATA_TYPE_INT16:
    return {atoms::s, 16};
  case ONNX_TENSOR_ELEMENT_DATA_TYPE_INT32:
    return {atoms::s, 32};
  case ONNX_TENSOR_ELEMENT_DATA_TYPE_INT64:
    return {atoms::s, 64};
  case ONNX_TENSOR_ELEMENT_DATA_TYPE_UINT8:
    return {atoms::u, 8};
  case ONNX_TENSOR_ELEMENT_DATA_TYPE_UINT16:
    return {atoms::u, 16};
  case ONNX_TENSOR_ELEMENT_DATA_TYPE_UINT32:
    return {atoms::u, 32};
  case ONNX_TENSOR_ELEMENT_DATA_TYPE_UINT64:
    return {atoms::u, 64};
  case ONNX_TENSOR_ELEMENT_DATA_TYPE_BOOL:
    return {atoms::pred, 8};
  default:
    throw std::invalid_argument("unsupported ONNX tensor element type");
  }
}

static std::string dtype_name(ONNXTensorElementDataType type) {
  switch (type) {
  case ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT16:
    return "Float16";
  case ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT:
    return "Float32";
  case ONNX_TENSOR_ELEMENT_DATA_TYPE_DOUBLE:
    return "Float64";
  case ONNX_TENSOR_ELEMENT_DATA_TYPE_BFLOAT16:
    return "BFloat16";
  case ONNX_TENSOR_ELEMENT_DATA_TYPE_INT8:
    return "Int8";
  case ONNX_TENSOR_ELEMENT_DATA_TYPE_INT16:
    return "Int16";
  case ONNX_TENSOR_ELEMENT_DATA_TYPE_INT32:
    return "Int32";
  case ONNX_TENSOR_ELEMENT_DATA_TYPE_INT64:
    return "Int64";
  case ONNX_TENSOR_ELEMENT_DATA_TYPE_UINT8:
    return "UInt8";
  case ONNX_TENSOR_ELEMENT_DATA_TYPE_UINT16:
    return "UInt16";
  case ONNX_TENSOR_ELEMENT_DATA_TYPE_UINT32:
    return "UInt32";
  case ONNX_TENSOR_ELEMENT_DATA_TYPE_UINT64:
    return "UInt64";
  case ONNX_TENSOR_ELEMENT_DATA_TYPE_BOOL:
    return "Bool";
  default:
    return "Unknown";
  }
}

static int64_t element_count(const std::vector<int64_t> &shape) {
  if (shape.empty())
    return 1;

  return std::accumulate(shape.begin(), shape.end(), int64_t{1},
                         [](int64_t acc, int64_t dim) {
                           if (dim < 0)
                             throw std::invalid_argument(
                                 "tensor shape cannot contain dynamic dimensions");
                           return acc * dim;
                         });
}

class Tensor {
public:
  Tensor(ErlNifBinary binary, std::vector<int64_t> shape, DTypeTerm dtype_term)
      : shape(std::move(shape)), dtype(decode_dtype(dtype_term)),
        data(binary.data, binary.data + binary.size) {
    auto expected_size =
        static_cast<size_t>(element_count(this->shape)) * element_size(dtype);

    if (expected_size != data.size()) {
      std::ostringstream message;
      message << "binary size " << data.size() << " does not match tensor size "
              << expected_size;
      throw std::invalid_argument(message.str());
    }
  }

  explicit Tensor(Ort::Value &&output) {
    auto info = output.GetTensorTypeAndShapeInfo();
    dtype = info.GetElementType();
    shape = info.GetShape();

    auto bytes = info.GetElementCount() * element_size(dtype);
    data.resize(bytes);
    std::memcpy(data.data(), output.GetTensorRawData(), bytes);
  }

  Ort::Value ort_value() const {
    auto memory = Ort::MemoryInfo::CreateCpu(OrtArenaAllocator, OrtMemTypeDefault);
    return Ort::Value::CreateTensor(memory, const_cast<uint8_t *>(data.data()),
                                    data.size(), shape.data(), shape.size(),
                                    dtype);
  }

  const std::vector<int64_t> &dims() const { return shape; }
  ONNXTensorElementDataType element_type() const { return dtype; }

  fine::Term to_binary(ErlNifEnv *env, uint64_t limit) const {
    auto bytes = data.size();

    if (limit > 0) {
      auto max_bytes = limit * element_size(dtype);
      bytes = std::min<uint64_t>(bytes, max_bytes);
    }

    return fine::make_new_binary(
        env, reinterpret_cast<const char *>(data.data()), bytes);
  }

private:
  std::vector<int64_t> shape;
  ONNXTensorElementDataType dtype;
  std::vector<uint8_t> data;
};

FINE_RESOURCE(Tensor);

class Session {
public:
  Session(std::string path, std::vector<fine::Atom> execution_providers,
          int64_t optimization_level)
      : session(nullptr) {
    Ort::SessionOptions options;
    options.SetGraphOptimizationLevel(graph_optimization_level(optimization_level));

    for (auto &provider : execution_providers) {
      if (provider.to_string() != atoms::cpu.to_string()) {
        throw std::invalid_argument(
            "only the :cpu execution provider is currently supported");
      }
    }

    session = Ort::Session(ort_env(), path.c_str(), options);
    read_io_metadata();
  }

  std::vector<
      std::tuple<fine::ResourcePtr<Tensor>, std::vector<int64_t>, fine::Atom,
                 uint64_t>>
  run(std::vector<fine::ResourcePtr<Tensor>> inputs) {
    if (inputs.size() != input_name_ptrs.size()) {
      std::ostringstream message;
      message << "expected " << input_name_ptrs.size() << " inputs, got "
              << inputs.size();
      throw std::invalid_argument(message.str());
    }

    std::vector<Ort::Value> input_values;
    input_values.reserve(inputs.size());

    for (auto &input : inputs) {
      input_values.emplace_back(input->ort_value());
    }

    auto outputs = session.Run(Ort::RunOptions{nullptr}, input_name_ptrs.data(),
                               input_values.data(), input_values.size(),
                               output_name_ptrs.data(), output_name_ptrs.size());

    std::vector<std::tuple<fine::ResourcePtr<Tensor>, std::vector<int64_t>,
                           fine::Atom, uint64_t>>
        result;
    result.reserve(outputs.size());

    for (auto &output : outputs) {
      auto tensor = fine::make_resource<Tensor>(std::move(output));
      auto [kind, bits] = encode_dtype(tensor->element_type());
      result.emplace_back(tensor, tensor->dims(), kind, bits);
    }

    return result;
  }

  std::tuple<std::vector<IOTerm>, std::vector<IOTerm>> show() const {
    return {inputs, outputs};
  }

private:
  static GraphOptimizationLevel graph_optimization_level(int64_t level) {
    switch (level) {
    case 1:
      return ORT_ENABLE_BASIC;
    case 2:
      return ORT_ENABLE_EXTENDED;
    case 3:
      return ORT_ENABLE_ALL;
    default:
      return ORT_DISABLE_ALL;
    }
  }

  static ShapeTerm shape_term(const std::vector<int64_t> &shape) {
    ShapeTerm result;
    result.reserve(shape.size());

    for (auto dim : shape) {
      if (dim < 0) {
        result.push_back(std::nullopt);
      } else {
        result.push_back(dim);
      }
    }

    return result;
  }

  static IOTerm io_term(const std::string &name, const Ort::TypeInfo &type_info) {
    if (type_info.GetONNXType() != ONNX_TYPE_TENSOR) {
      return {name, "NonTensor", {}};
    }

    auto tensor_info = type_info.GetTensorTypeAndShapeInfo();
    return {name, dtype_name(tensor_info.GetElementType()),
            shape_term(tensor_info.GetShape())};
  }

  void read_io_metadata() {
    Ort::AllocatorWithDefaultOptions allocator;

    auto input_count = session.GetInputCount();
    input_names.reserve(input_count);
    input_name_ptrs.reserve(input_count);
    inputs.reserve(input_count);

    for (size_t i = 0; i < input_count; ++i) {
      auto name = session.GetInputNameAllocated(i, allocator);
      input_names.emplace_back(name.get());
      input_name_ptrs.push_back(input_names.back().c_str());
      inputs.push_back(io_term(input_names.back(), session.GetInputTypeInfo(i)));
    }

    auto output_count = session.GetOutputCount();
    output_names.reserve(output_count);
    output_name_ptrs.reserve(output_count);
    outputs.reserve(output_count);

    for (size_t i = 0; i < output_count; ++i) {
      auto name = session.GetOutputNameAllocated(i, allocator);
      output_names.emplace_back(name.get());
      output_name_ptrs.push_back(output_names.back().c_str());
      outputs.push_back(io_term(output_names.back(), session.GetOutputTypeInfo(i)));
    }
  }

  Ort::Session session;
  std::vector<std::string> input_names;
  std::vector<std::string> output_names;
  std::vector<const char *> input_name_ptrs;
  std::vector<const char *> output_name_ptrs;
  std::vector<IOTerm> inputs;
  std::vector<IOTerm> outputs;
};

FINE_RESOURCE(Session);

fine::ResourcePtr<Session> init(ErlNifEnv *, std::string path,
                                std::vector<fine::Atom> execution_providers,
                                int64_t optimization_level) {
  return fine::make_resource<Session>(std::move(path), execution_providers,
                                      optimization_level);
}

std::vector<std::tuple<fine::ResourcePtr<Tensor>, std::vector<int64_t>,
                       fine::Atom, uint64_t>>
run(ErlNifEnv *, fine::ResourcePtr<Session> session,
    std::vector<fine::ResourcePtr<Tensor>> inputs) {
  return session->run(std::move(inputs));
}

std::tuple<std::vector<IOTerm>, std::vector<IOTerm>>
show_session(ErlNifEnv *, fine::ResourcePtr<Session> session) {
  return session->show();
}

fine::ResourcePtr<Tensor> from_binary(ErlNifEnv *, ErlNifBinary binary,
                                      std::vector<int64_t> shape,
                                      DTypeTerm dtype) {
  return fine::make_resource<Tensor>(binary, std::move(shape), dtype);
}

fine::Term to_binary(ErlNifEnv *env, fine::ResourcePtr<Tensor> tensor,
                     uint64_t limit) {
  return tensor->to_binary(env, limit);
}

FINE_NIF(init, 0);
FINE_NIF(run, ERL_NIF_DIRTY_JOB_CPU_BOUND);
FINE_NIF(show_session, 0);
FINE_NIF(from_binary, 0);
FINE_NIF(to_binary, 0);

FINE_INIT("Elixir.OnnxRuntime.Native");
