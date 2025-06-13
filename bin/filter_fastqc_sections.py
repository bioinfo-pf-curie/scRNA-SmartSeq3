from pathlib import Path
import sys

if len(sys.argv) != 2:
    print("Usage : python filter_fastqc_sections.py <chemin_du_dossier_fastqc>")
    sys.exit(1)

input_dir = Path(sys.argv[1])

wanted_sections = {
    "Per base sequence quality",
    "Sequence Duplication Levels",
    "Per base sequence content",
    "Overrepresented sequences"
}

for fastqc_file in input_dir.rglob("fastqc_data.txt"):
    with fastqc_file.open("r") as f:
        lines = f.readlines()

    keep = False
    new_lines = []

    for line in lines:
        if line.startswith(">>"):
            section_title = line[2:].strip().rsplit("\t", 1)[0]
            keep = section_title in wanted_sections or line.startswith(">>END_MODULE")
        if keep:
            new_lines.append(line)

    with fastqc_file.open("w") as f:
        f.writelines(new_lines)

print(f"Filtrage terminé dans : {input_dir}")
