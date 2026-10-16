#define _GNU_SOURCE
#include <wayland-client.h>
#include <sys/mman.h>
#include <unistd.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include "idle-inhibit-client.h"
#include "layer-shell-client.h"

static struct wl_display *display;
static struct wl_compositor *compositor;
static struct wl_shm *shm;
static struct zwlr_layer_shell_v1 *layers;
static struct zwp_idle_inhibit_manager_v1 *manager;
static struct wl_surface *surface;
static struct wl_buffer *buffer;
static int configured;

static void global(void *data, struct wl_registry *registry, uint32_t name, const char *interface, uint32_t version) {
    if (!strcmp(interface, "wl_compositor")) compositor = wl_registry_bind(registry, name, &wl_compositor_interface, 1);
    if (!strcmp(interface, "wl_shm")) shm = wl_registry_bind(registry, name, &wl_shm_interface, 1);
    if (!strcmp(interface, "zwlr_layer_shell_v1")) layers = wl_registry_bind(registry, name, &zwlr_layer_shell_v1_interface, 1);
    if (!strcmp(interface, "zwp_idle_inhibit_manager_v1")) manager = wl_registry_bind(registry, name, &zwp_idle_inhibit_manager_v1_interface, 1);
}
static void removed(void *data, struct wl_registry *registry, uint32_t name) {}
static const struct wl_registry_listener registry_listener = { global, removed };
static void configure(void *data, struct zwlr_layer_surface_v1 *layer, uint32_t serial, uint32_t width, uint32_t height) {
    zwlr_layer_surface_v1_ack_configure(layer, serial);
    wl_surface_attach(surface, buffer, 0, 0);
    wl_surface_damage(surface, 0, 0, 1, 1);
    wl_surface_commit(surface);
    configured = 1;
}
static void closed(void *data, struct zwlr_layer_surface_v1 *layer) { exit(1); }
static const struct zwlr_layer_surface_v1_listener layer_listener = { configure, closed };
int main(void) {
    display = wl_display_connect(NULL);
    if (!display) return 1;
    struct wl_registry *registry = wl_display_get_registry(display);
    wl_registry_add_listener(registry, &registry_listener, NULL);
    wl_display_roundtrip(display);
    if (!compositor || !shm || !layers || !manager) return 2;
    int fd = memfd_create("pleamar-inhibitor", MFD_CLOEXEC);
    if (fd < 0 || ftruncate(fd, 4) < 0) return 3;
    void *pixels = mmap(NULL, 4, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
    if (pixels == MAP_FAILED) return 3;
    memset(pixels, 0, 4);
    struct wl_shm_pool *pool = wl_shm_create_pool(shm, fd, 4);
    buffer = wl_shm_pool_create_buffer(pool, 0, 1, 1, 4, WL_SHM_FORMAT_ARGB8888);
    wl_shm_pool_destroy(pool);
    close(fd);
    surface = wl_compositor_create_surface(compositor);
    struct wl_region *empty = wl_compositor_create_region(compositor);
    wl_surface_set_input_region(surface, empty);
    wl_region_destroy(empty);
    struct zwlr_layer_surface_v1 *layer = zwlr_layer_shell_v1_get_layer_surface(layers, surface, NULL, ZWLR_LAYER_SHELL_V1_LAYER_OVERLAY, "pleamar-idle-inhibitor");
    zwlr_layer_surface_v1_set_size(layer, 1, 1);
    zwlr_layer_surface_v1_set_anchor(layer, ZWLR_LAYER_SURFACE_V1_ANCHOR_TOP | ZWLR_LAYER_SURFACE_V1_ANCHOR_LEFT);
    zwlr_layer_surface_v1_set_exclusive_zone(layer, -1);
    zwlr_layer_surface_v1_set_keyboard_interactivity(layer, ZWLR_LAYER_SURFACE_V1_KEYBOARD_INTERACTIVITY_NONE);
    zwlr_layer_surface_v1_add_listener(layer, &layer_listener, NULL);
    wl_surface_commit(surface);
    while (!configured && wl_display_dispatch(display) >= 0) {}
    if (!configured) return 4;
    if (wl_display_roundtrip(display) < 0) return 4;
    struct zwp_idle_inhibitor_v1 *inhibitor = zwp_idle_inhibit_manager_v1_create_inhibitor(manager, surface);
    if (wl_display_roundtrip(display) < 0) return 4;
    puts("ready");
    fflush(stdout);
    while (wl_display_dispatch(display) >= 0) {}
    zwp_idle_inhibitor_v1_destroy(inhibitor);
    wl_display_disconnect(display);
    return 0;
}
