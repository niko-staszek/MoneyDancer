import sys
with open(sys.argv[1], "rb") as f:
    data = f.read()
text = data.decode("utf-16le", errors="replace").replace("\r\n", "\n").lstrip("﻿")
sys.stdout.buffer.write(text.encode("utf-8", errors="replace"))
