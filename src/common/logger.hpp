#ifndef COMMON_LOGGER_HPP
#define COMMON_LOGGER_HPP

#ifndef SPDLOG_ACTIVE_LEVEL
    #ifdef NDEBUG
        #define SPDLOG_ACTIVE_LEVEL SPDLOG_LEVEL_WARN
    #else
        #define SPDLOG_ACTIVE_LEVEL SPDLOG_LEVEL_TRACE
    #endif
#endif

#include <bits/shared_ptr.h>
#include <fmt/base.h>
#include <memory>
#include <spdlog/common.h>
#include <spdlog/logger.h>
#include <spdlog/sinks/stdout_color_sinks.h>
#include <spdlog/spdlog.h>
#include <utility>

namespace common {

/// Singleton logger wrapper around spdlog
class Logger final
{
  public:
    /// Get the singleton logger instance
    static auto instance() -> Logger &
    {
        static Logger instance;
        return instance;
    }

    Logger(const Logger &) = delete;
    auto operator=(const Logger &) -> Logger & = delete;
    Logger(Logger &&) = delete;
    auto operator=(Logger &&) -> Logger & = delete;
    ~Logger() = default;

    template<typename... Args>
    auto trace([[maybe_unused]] fmt::format_string<Args...> fmt, [[maybe_unused]] Args &&...args)
      -> void
    {
        SPDLOG_LOGGER_TRACE(logger_, fmt, std::forward<Args>(args)...);
    }

    template<typename... Args>
    auto debug([[maybe_unused]] fmt::format_string<Args...> fmt, [[maybe_unused]] Args &&...args)
      -> void
    {
        SPDLOG_LOGGER_DEBUG(logger_, fmt, std::forward<Args>(args)...);
    }

    template<typename... Args>
    auto info([[maybe_unused]] fmt::format_string<Args...> fmt, [[maybe_unused]] Args &&...args)
      -> void
    {
        SPDLOG_LOGGER_INFO(logger_, fmt, std::forward<Args>(args)...);
    }

    template<typename... Args>
    auto warn([[maybe_unused]] fmt::format_string<Args...> fmt, [[maybe_unused]] Args &&...args)
      -> void
    {
        SPDLOG_LOGGER_WARN(logger_, fmt, std::forward<Args>(args)...);
    }

    template<typename... Args>
    auto error([[maybe_unused]] fmt::format_string<Args...> fmt, [[maybe_unused]] Args &&...args)
      -> void
    {
        SPDLOG_LOGGER_ERROR(logger_, fmt, std::forward<Args>(args)...);
    }

    template<typename... Args>
    auto critical([[maybe_unused]] fmt::format_string<Args...> fmt, [[maybe_unused]] Args &&...args)
      -> void
    {
        SPDLOG_LOGGER_CRITICAL(logger_, fmt, std::forward<Args>(args)...);
    }

  private:
    Logger() :
      logger_([] -> std::shared_ptr<std::_NonArray<spdlog::logger>> {
          auto console_sink = std::make_shared<spdlog::sinks::stdout_color_sink_mt>();
          console_sink->set_level(static_cast<spdlog::level::level_enum>(SPDLOG_ACTIVE_LEVEL));
          console_sink->set_pattern("[%Y-%m-%d %H:%M:%S.%e] [%^%l%$] %v");

          auto logger = std::make_shared<spdlog::logger>("", console_sink);
          logger->set_level(console_sink->level());
          logger->flush_on(spdlog::level::err);

          return logger;
      }())
    {
    }

    std::shared_ptr<spdlog::logger> logger_;
};

} // namespace common

#endif /* COMMON_LOGGER_HPP */
