#pragma once

#include <cstdint>
#include <string>
#include <vector>

namespace mealplan_codec {

static inline bool is_space(char c) {
  return c == ' ' || c == '\n' || c == '\r' || c == '\t';
}

static inline std::string base64_encode(const std::vector<uint8_t> &data) {
  static const char *alphabet =
      "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

  if (data.empty()) return "";

  std::string out;
  out.reserve(((data.size() + 2) / 3) * 4);

  size_t i = 0;
  while (i + 3 <= data.size()) {
    const uint32_t n = (uint32_t(data[i]) << 16) | (uint32_t(data[i + 1]) << 8) |
                       uint32_t(data[i + 2]);
    out.push_back(alphabet[(n >> 18) & 0x3F]);
    out.push_back(alphabet[(n >> 12) & 0x3F]);
    out.push_back(alphabet[(n >> 6) & 0x3F]);
    out.push_back(alphabet[n & 0x3F]);
    i += 3;
  }

  const size_t rem = data.size() - i;
  if (rem == 1) {
    const uint32_t n = (uint32_t(data[i]) << 16);
    out.push_back(alphabet[(n >> 18) & 0x3F]);
    out.push_back(alphabet[(n >> 12) & 0x3F]);
    out.push_back('=');
    out.push_back('=');
  } else if (rem == 2) {
    const uint32_t n = (uint32_t(data[i]) << 16) | (uint32_t(data[i + 1]) << 8);
    out.push_back(alphabet[(n >> 18) & 0x3F]);
    out.push_back(alphabet[(n >> 12) & 0x3F]);
    out.push_back(alphabet[(n >> 6) & 0x3F]);
    out.push_back('=');
  }

  return out;
}

static inline int base64_value(unsigned char c) {
  if (c >= 'A' && c <= 'Z') return c - 'A';
  if (c >= 'a' && c <= 'z') return 26 + (c - 'a');
  if (c >= '0' && c <= '9') return 52 + (c - '0');
  if (c == '+') return 62;
  if (c == '/') return 63;
  return -1;
}

static inline bool base64_decode(const std::string &input,
                                std::vector<uint8_t> *out,
                                std::string *error = nullptr) {
  if (!out) return false;
  out->clear();

  // Accept empty string as "no schedule" / clear.
  if (input.empty()) return true;

  // Strip whitespace.
  std::string in;
  in.reserve(input.size());
  for (char c : input) {
    if (!is_space(c)) in.push_back(c);
  }

  // Treat placeholder values as invalid to avoid accidental clears.
  if (in == "unknown") {
    if (error) *error = "Unknown placeholder value";
    return false;
  }

  if ((in.size() % 4) != 0) {
    if (error) *error = "Invalid base64 length";
    return false;
  }

  out->reserve((in.size() / 4) * 3);

  for (size_t i = 0; i < in.size(); i += 4) {
    const unsigned char c0 = (unsigned char) in[i];
    const unsigned char c1 = (unsigned char) in[i + 1];
    const unsigned char c2 = (unsigned char) in[i + 2];
    const unsigned char c3 = (unsigned char) in[i + 3];

    const int v0 = base64_value(c0);
    const int v1 = base64_value(c1);

    if (v0 < 0 || v1 < 0) {
      if (error) *error = "Invalid base64 character";
      return false;
    }

    const bool pad2 = (c2 == '=');
    const bool pad3 = (c3 == '=');

    const int v2 = pad2 ? 0 : base64_value(c2);
    const int v3 = pad3 ? 0 : base64_value(c3);

    if ((!pad2 && v2 < 0) || (!pad3 && v3 < 0)) {
      if (error) *error = "Invalid base64 character";
      return false;
    }

    const uint32_t n = (uint32_t(v0) << 18) | (uint32_t(v1) << 12) |
                       (uint32_t(v2) << 6) | uint32_t(v3);

    out->push_back((n >> 16) & 0xFF);
    if (!pad2) out->push_back((n >> 8) & 0xFF);
    if (!pad3) out->push_back(n & 0xFF);

    // '=' can only appear in the last quartet.
    if ((pad2 || pad3) && (i + 4) != in.size()) {
      if (error) *error = "Invalid base64 padding";
      return false;
    }
  }

  return true;
}

}  // namespace mealplan_codec
