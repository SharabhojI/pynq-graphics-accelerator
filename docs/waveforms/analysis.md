### Command Processor – CLEAR Command

This waveform shows the command processor FSM transitioning from IDLE through header and payload phases, dispatching a CLEAR command, waiting for the clear_done handshake, and returning to IDLE.
![Command Processor, CLEAR command waveform](command_processor_clear_decoded.png)

### Command Processor – DRAW_TRIANGLE Command
This waveform showis the successful execution of a DRAW_TRIANGLE command, including header decode, six-word payload buffering, transition to EXECUTE, raster_start assertion, raster_done handshake, and return to IDLE.
![Command Processor, DRAW_TRIANGLE command waveform](command_processor_draw_triangle.png)