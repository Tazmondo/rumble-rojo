import subprocess

x = (subprocess.check_output(['git', 'ls-files'])).decode('utf-8')

filenames = x.strip().split("\n")
validExts = ['lua']

loc = 0
fileCount = 0

for filename in filenames:
    if filename.split(".")[-1] in validExts and not "Iris" in filename and not "ProfileService" in filename and not "Spring" in filename:
        with open(filename, "r") as f:
            length = len(f.readlines())
            loc += length
            print(f'{filename} : {length}')
            fileCount += 1

print(f"\nFile Count: {fileCount}\nLines of Code: {loc}")