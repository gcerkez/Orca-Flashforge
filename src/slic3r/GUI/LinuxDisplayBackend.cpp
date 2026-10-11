#include "LinuxDisplayBackend.hpp"

#if defined(__WXGTK__)

#include <gdk/gdk.h>
#include <cstdlib>
#include <cstring>

#if defined(wxHAVE_GDK_X11) || defined(GDK_WINDOWING_X11)
#include <gdk/gdkx.h>
#endif

#if defined(wxHAVE_GDK_WAYLAND) || defined(GDK_WINDOWING_WAYLAND)
#include <gdk/gdkwayland.h>
#endif

namespace Slic3r {
namespace GUI {

LinuxDisplayBackend get_linux_display_backend()
{
    static LinuxDisplayBackend cached_backend = LinuxDisplayBackend::Unknown;
    static bool cached = false;

    if (cached)
        return cached_backend;

    GdkDisplay *display = gdk_display_get_default();
    if (display) {
#if defined(wxHAVE_GDK_WAYLAND) || defined(GDK_WINDOWING_WAYLAND)
        if (GDK_IS_WAYLAND_DISPLAY(display)) {
            cached_backend = LinuxDisplayBackend::Wayland;
            cached = true;
            return cached_backend;
        }
#endif

#if defined(wxHAVE_GDK_X11) || defined(GDK_WINDOWING_X11)
        if (GDK_IS_X11_DISPLAY(display)) {
            cached_backend = LinuxDisplayBackend::X11;
            cached = true;
            return cached_backend;
        }
#endif
    }

    const char *session = std::getenv("XDG_SESSION_TYPE");
    if (session && std::strcmp(session, "wayland") == 0)
        return LinuxDisplayBackend::Wayland;
    if (session && std::strcmp(session, "x11") == 0)
        return LinuxDisplayBackend::X11;

    if (std::getenv("WAYLAND_DISPLAY"))
        return LinuxDisplayBackend::Wayland;

    return LinuxDisplayBackend::Unknown;
}

bool is_running_on_wayland()
{
    return get_linux_display_backend() == LinuxDisplayBackend::Wayland;
}

bool is_running_on_x11()
{
    return get_linux_display_backend() == LinuxDisplayBackend::X11;
}

} // namespace GUI
} // namespace Slic3r

#endif // defined(__WXGTK__)