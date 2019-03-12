import utils.mif_writer
from utils.parser import entityparser

# def_pkg parser
vhdl_src_folder = ".\\vhdl_src_files\\"
def_pkg_path = ".\\const_def_pkg.vhd"

# .mif files for ROM
mif_folder = ".\\mif_files\\"


## generate .mif files
utils.mif_writer.window_rom(mif_folder)
utils.mif_writer.distance_rom(mif_folder)

## add dashtable with used constants to every VHDL source file
# modules.constants_crawler.run(vhdl_src_folder, def_pkg_path)