# -*- coding: utf-8 -*-
"""Start the installed rhino-gh-mcp listener without toggling it off.

Run inside Rhino 8 with RunPythonScript (IronPython 2.7 compatible).
"""
import Rhino
from System.Net.NetworkInformation import IPGlobalProperties


def listener_available():
    # Read listener state without opening an empty MCP client connection.
    listeners = IPGlobalProperties.GetIPGlobalProperties().GetActiveTcpListeners()
    return any(endpoint.Port == 9876 and
               str(endpoint.Address) in ("127.0.0.1", "0.0.0.0", "::", "::1")
               for endpoint in listeners)


def main():
    if listener_available():
        Rhino.RhinoApp.WriteLine("MCP is already running on 127.0.0.1:9876.")
        return
    if not Rhino.RhinoApp.RunScript("_ToggleMcpService", False):
        Rhino.RhinoApp.WriteLine("MCP startup failed. Check the rhino-gh-mcp plugin.")
        return
    if listener_available():
        Rhino.RhinoApp.WriteLine("MCP is ready on 127.0.0.1:9876.")
    else:
        Rhino.RhinoApp.WriteLine("MCP listener is not ready. Check Rhino command history.")


if __name__ == "__main__":
    main()
