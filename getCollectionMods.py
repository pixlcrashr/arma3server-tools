
import requests, json, sys, os

if len(sys.argv) != 3:
    print()
    sys.exit(0)

apiKey = sys.argv[1] # apikey
collectionID = sys.argv[2] # collectionid
request = requests.post('https://api.steampowered.com/ISteamRemoteStorage/GetCollectionDetails/v1/', data={'key': apiKey, 'collectioncount': 1, 'publishedfileids[0]': collectionID})
decodedJson = json.loads(request.text)

mods = ""

for workshopMod in decodedJson["response"]["collectiondetails"][0]["children"]:
    mods += workshopMod["publishedfileid"] + " "

print(mods)
