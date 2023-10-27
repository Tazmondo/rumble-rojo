import subprocess

x = (subprocess.check_output(['git', 'ls-files'])).decode('utf-8')

filenames = x.strip().split("\n")
validExts = ['lua']

loc = 0
fileCount = 0
eventCount = 0
commandCount = 0

for filename in filenames:
    if filename.split(".")[-1] in validExts and not "Iris" in filename and not "ProfileService" in filename and not "Spring" in filename:
        with open(filename, "r") as f:
            length = len(f.readlines())
            loc += length
            print(f'{filename} : {length}')
            fileCount += 1

            if "Commands/" in filename:
                commandCount += 1
            
            if "Events/" in filename:
                eventCount += 1

print(f"\nModuleScript Count: {fileCount}\nEvents: {eventCount}\nCommands: {commandCount}\nModules: {fileCount - commandCount - eventCount}\nLines of Code: {loc}")