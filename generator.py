import modules.mif_writer as mif_writer
import modules.constants_crawler as constants_crawler


# def_pkg parser
vhdl_src_folder = ".\\vhdl_src_files\\"
def_pkg_path = ".\\const_def_pkg.vhd"

# .mif files for ROM
mif_folder = ".\\mif_files\\"


## generate .mif files
# mif_writer.window_rom(mif_folder)
# mif_writer.distance_rom(mif_folder)

## add dashtable with used constants to every VHDL source file
constants_crawler.run(vhdl_src_folder, def_pkg_path)