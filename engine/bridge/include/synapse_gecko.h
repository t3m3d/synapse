#ifndef SYNAPSE_GECKO_H
#define SYNAPSE_GECKO_H

#include <stdint.h>

#if defined(_WIN32)
#  if defined(SYNAPSE_GECKO_BUILD)
#    define SYNAPSE_API __declspec(dllexport)
#  else
#    define SYNAPSE_API __declspec(dllimport)
#  endif
#else
#  define SYNAPSE_API __attribute__((visibility("default")))
#endif

#ifdef __cplusplus
extern "C" {
#endif

#define SYNAPSE_GECKO_ABI_VERSION 1u

typedef struct SynapseEngine SynapseEngine;

/*
 * Future separation boundary. Initial Firefox-derived build does not use this
 * ABI yet. Keeping contract here prevents Krypton product logic from depending
 * on raw Gecko/XPCOM pointers later.
 *
 * All input JSON is borrowed UTF-8. All event JSON is owned by adapter and must
 * be released exactly once with synapse_engine_free_string().
 */
SYNAPSE_API SynapseEngine* synapse_engine_create(const char* config_json);

SYNAPSE_API uint32_t synapse_engine_command(
    SynapseEngine* engine,
    const char* command_json);

SYNAPSE_API char* synapse_engine_poll(SynapseEngine* engine);

SYNAPSE_API void synapse_engine_free_string(char* owned_string);

SYNAPSE_API void synapse_engine_destroy(SynapseEngine* engine);

#ifdef __cplusplus
}
#endif

#endif
