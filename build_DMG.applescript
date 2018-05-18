---------------------------------------------------------------------------------------------------------------------------
-- Nom du fichier :    build_DMG.applescript
---------------------------------------------------------------------------------------------------------------------------
-- Description      :    Crée une image DMG d'installation à partir d'un fichier .app.
---------------------------------------------------------------------------------------------------------------------------
-- Remarques      :
--				    - Le script demande de rechercher l'application
--				    - Il faut mettre l'image d'arrière-plan dans le même répertoire que le script (background.png) ou dans le dossier "Resources" de l'application build_DMG, sinon on demande le fichier à l'utilisateur
--				    - Image DMG en lecture seule
--				    - Image DMG en montage automatique
--				    - Image DMG compressée
--				    - Nécessite les droits d'administrateur
--				    - testé sur Mac OS X 10.12.6
---------------------------------------------------------------------------------------------------------------------------

property nomImageFond : "background.png"

-- Récupère un alias vers le dossier .app
set aliasFichierApp to choose file with prompt "Veuillez indiquez votre application."

-- Récupère un alias vers l'image d'arrière-plan background.png
-- Pour les tests, dans le même dossier que le script
-- En production, dans le dossier "Resources"
-- Sinon, on demande le fichier à l'utilisateur et il faut noter son nom
try
	set aliasImageFond to ((dossierParent(path to me) as text) & nomImageFond) as alias
on error
	try
		set aliasImageFond to (path to resource nomImageFond)
	on error
		set aliasImageFond to choose file with prompt "Impossible de trouver une image d'arrière-plan. Veuillez en indiquer une."
		
		tell application "Finder" to set nomImageFond to name of aliasImageFond
	end try
end try

-- Récupère le nom de l'application
tell application "Finder" to set nomApp to displayed name of aliasFichierApp

-- Récupère le numéro de version de l'application
set versionApp to versionApplication(aliasFichierApp)

-- Crée le nom du dossier de travail
set nomDossierDMG to nomApp & " " & versionApp -- exemple "Facture 1.2.4"

-- Crée le dossier de travail sur le bureau
set aliasDossierDMG to creeDossier(nomDossierDMG, path to desktop)

-- Crée un sous-dossier "background" dans le dossier de travail
-- (et non pas ".background" car Finder ne peut pas copier dans un dossier caché)
set aliasDossierBackground to creeDossier("background", aliasDossierDMG)

-- Copie l'image d'arrière-plan dans le sous-dossier "background" du dossier de travail
copieDansDossier(aliasImageFond, aliasDossierBackground)

-- Copie l'application dans le dossier de travail
set aliasFichierApp to copieDansDossier(aliasFichierApp, aliasDossierDMG)

-- Renomme le fichier application pour lui ajouter le numéro de version => ex : Facture 1.2.4
renommeApplication(aliasFichierApp, nomDossierDMG)

-- Crée un alias vers le dossier "/Applications" dans le dossier de travail
creeAlias((path to applications folder) as alias, aliasDossierDMG)

-- Crée une image DMG du dossier de travail => tmp.dmg en lecture/écriture et sans compression
set aliasImageDMG to transformeDossierEnImageDMG(aliasDossierDMG, "tmp.dmg", true, false)

-- Monte l'image DMG
set cheminDisque to monteImageDMG(aliasImageDMG)

-- Mets l'image en montage automatique
set cheminDisque to disqueEnMontageAutomatique(cheminDisque)

-- Modifie la présentation du dossier image
formateDossierDMG(POSIXVersAlias(cheminDisque))

-- Cache le fichier background (en le renommant en .background)
set aliasDossierBackground to ((POSIXVersAlias(cheminDisque) as text) & "background") as alias
renommeElementFinder(aliasDossierBackground, ".background")

-- Démonte le disque
demonteImageDMG(cheminDisque)

-- On crée l'image finale (ex : Facture 1.2.4.dmg)
transformeImageDMGEnImageDMG("tmp.dmg", nomDossierDMG & ".dmg", true, true)



(*  Nettoyage final  *)

-- Supprime le dossier de travail
supprimeElement(aliasDossierDMG)

-- On supprime l'image dmg temporaire
supprimeElement(((path to desktop as text) & "tmp.dmg") as alias)



display notification "Votre fichier d'installation est créé sur le bureau" with title "build_DMG" subtitle nomDossierDMG & ".dmg"


-----------------------------------------------------------------------------------------------------------
--                                                     FONCTIONS
-----------------------------------------------------------------------------------------------------------


-----------------------------------------------------------------------------------------------------------
--                                                   IMAGE DMG
-----------------------------------------------------------------------------------------------------------



(*
Nom                	: transformeDossierEnImageDMG 
Description       	: Crée un fichier DMG à partir d'un dossier passé en paramètre
aliasDossier 		: alias vers le dossier
nomImageDMG	: nom de l'image à créer
lectureEcriture 	: indique si l'image est en lecture/écriture (booléen)
compression 		: indique si l'image est compressée ou non (booléen)
retour			: alias vers l'image DMG créée
Remarques		: "hdiutil info" pour voir les caractéristiques du disque monté
*)
on transformeDossierEnImageDMG(aliasDossier, nomImageDMG, lectureEcriture, compression)
	
	set cheminPOSIXDossierParent to POSIX path of dossierParent(aliasDossier)
	set nomDossier to name of (info for aliasDossier)
	set volname to "Installez " & nomDossier
	set srcfolder to POSIX path of aliasDossier
	
	
	if lectureEcriture then
		set formatDMG to "UDRW"
	else
		set formatDMG to "UDZO"
	end if
	
	if compression then
		set imagekey to "-imagekey zlib-level=9"
	else
		set imagekey to ""
	end if
	
	set commande to "cd " & quoted form of cheminPOSIXDossierParent & ";hdiutil create -volname " & quoted form of volname & " -srcfolder " & quoted form of srcfolder & " -ov " & imagekey & " -format " & formatDMG & " " & quoted form of nomImageDMG
	
	do shell script commande with administrator privileges
	
	return (POSIX file (cheminPOSIXDossierParent & nomImageDMG)) as alias
	
end transformeDossierEnImageDMG


(*
Nom                	: monteImageDMG 
Description       	: Monte une image DMG
aliasImageDMG 	: alias vers le fichier image DMG
retour			: chaine POSIX du point de montage
*)
on monteImageDMG(aliasImageDMG)
	
	--hdiutil attach "tmp.dmg" -readwrite
	
	set commande to "hdiutil attach " & quoted form of (POSIX path of aliasImageDMG) & " -readwrite"
	
	set retourCommande to do shell script commande with administrator privileges
	
	set derniereLigne to last paragraph of retourCommande
	set ATID to AppleScript's text item delimiters
	set AppleScript's text item delimiters to "/Volumes/"
	set listeFiltree to text items of derniereLigne
	set AppleScript's text item delimiters to ATID
	set pointDeMontage to ("/Volumes/" & last item of listeFiltree)
	
	return pointDeMontage --("/Volumes/" & nomVolume)
	
end monteImageDMG


(*
Nom                	: demonteImageDMG 
Description       	: Éjecte un disque
pointDeMontage 	: Chemin POSIX du point de montage
retour			: RIEN
*)
on demonteImageDMG(pointDeMontage)
	
	--hdiutil detach /Volumes/Installez\ Facture\ 1.2.4/
	
	set commande to "hdiutil detach " & quoted form of (pointDeMontage)
	
	set retourCommande to do shell script commande with administrator privileges
	
	return retourCommande --("/Volumes/" & nomVolume)
	
end demonteImageDMG


(*
Nom                	: disqueEnMontageAutomatique 
Description       	: Modifie le disque pour qu'il se monte automatiquement la prochaine fois
pointDeMontage 	: Chemin POSIX du point de montage
retour			: Chemin POSIX du point de montage
*)
on disqueEnMontageAutomatique(pointDeMontage)
	
	-- Permet l'ouverture automatique dans le Finder lors du montage de l'image
	--sudo bless --folder "/Volumes/Installez Facture 1.2.4" --openfolder "/Volumes/Installez Facture 1.2.4"
	
	set commande to "bless --folder " & quoted form of pointDeMontage & " --openfolder " & quoted form of pointDeMontage
	
	do shell script commande with administrator privileges
	
	return pointDeMontage
	
end disqueEnMontageAutomatique



(*
Nom                	: formateDossierDMG 
Description       	: Modifie l'apparence d'un dossier qui deviendra un DMG d'installation
aliasDossierDMG 	: alias vers le dossier à modifier
retour			: RIEN
Remarques		: 
					- L'image d'arrière plan (nomImageFond) se trouve dans le dossier background
					- Modification de la taille de la fenêtre
					- Désactivation de la barre d'état
					- Vue en icônes
					- Taille des icônes à 144
					- Taille du texte à 16
					- Texte positionné en bas
					- Aucune organisation ni filtre
					- Aperçu des icônes activé
					- Modification de l'image d'arrière-plan
					- Repositionnement des icônes de l'application et du raccourci vers Applications
*)
on formateDossierDMG(aliasDossierDMG)
	
	set aliasImageFondDossier to ((aliasDossierDMG as text) & ":background:" & nomImageFond) as alias
	
	tell application "Finder"
		
		--set imageFondDossier to file nomImageFond of folder "background" of disk aliasDossierDMG
		open disk aliasDossierDMG
		
		tell front Finder window
			-- On modifie l'apparence du dossier
			set bounds to {309, 173, 1074, 614}
			-- On cache la barre d'état
			set statusbar visible to false
			
			set current view to icon view
			tell its icon view options
				set icon size to 144
				set text size to 16
				set label position to bottom
				set arrangement to not arranged
				set shows icon preview to true
				set background picture to aliasImageFondDossier
				--set background picture to imageFondDossier
			end tell
			
			-- On mémorise le dossier
			set nomDossierFenetre to target
			
			-- On place les icônes au bon endroit
			tell nomDossierFenetre
				repeat with i from 1 to count of items
					
					if (name of item i) is "Applications" then
						set position of item i to {217, 181}
					else
						set position of item i to {543, 181}
					end if
				end repeat
				
			end tell
			
		end tell
		
		-- Il faut fermer et rouvrir la fenêtre pour que les modifications apparaissent
		close front Finder window
		open nomDossierFenetre
		delay 2
		close nomDossierFenetre
		
	end tell
	
end formateDossierDMG



(*
Nom                			: transformeImageDMGEnImageDMG 
Description       			: Transforme un fichier DMG en un nouveau fichier DMG avec des caractéristiques différentes
nomImageDMGSource 		: nom de l'image à transformer
nomImageDMGDestination 	: nom de l'image finale
lectureSeule 				: indique si l'image est en lecture seule (booléen)
compression 				: indique si l'image est compressée (booléen)
retour					: retour de la commande utilisée pour la transformation
*)
on transformeImageDMGEnImageDMG(nomImageDMGSource, nomImageDMGDestination, lectureSeule, compression)
	
	--cd ~/Desktop;hdiutil convert "Facture 1.2.4.dmg" -format UDZO -imagekey zlib-level=9 -o "Facture final.dmg"
	
	set commande to "cd " & quoted form of (POSIX path of (path to desktop)) & ";hdiutil convert " & quoted form of nomImageDMGSource & " -format UDZO -imagekey zlib-level=9 -o " & quoted form of nomImageDMGDestination
	
	set retourCommande to do shell script commande with administrator privileges
	
	return retourCommande
	
end transformeImageDMGEnImageDMG


-----------------------------------------------------------------------------------------------------------
--                                                   FICHIERS/DOSSIERS
-----------------------------------------------------------------------------------------------------------



(*
Nom			: POSIXVersAlias 
Description	: Renvoi un alias à partir d'un chemin POSIX
cheminPOSIX : chaîne contenant un chemin complet POSIX sur un fichier/dossier
retour		: un alias vers le fichier/dossier
*)

on POSIXVersAlias(cheminPOSIX)
	return (POSIX file cheminPOSIX) as alias
end POSIXVersAlias



(*
Nom       		: aliasVersPOSIX 
Description 	: Renvoi un chemin POSIX à partir d'un alias
cheminAlias	: alias vers un fichier/dossier
retour 		: chaine contenant un chemin POSIX vers le fichier/dossier
*)
on aliasVersPOSIX(cheminAlias)
	return POSIX path of cheminAlias
end aliasVersPOSIX


(*
Nom                	: versionApplication 
Description       	: Renvoi la version de l'application
aliasApplication 	: alias vers l'application
retour			: chaine contenant le numéro de version de l'application
*)
on versionApplication(aliasApplication)
	return do shell script "defaults read " & quoted form of ((POSIX path of aliasApplication) & "Contents/Info.plist") & " CFBundleShortVersionString"
end versionApplication



(*
Nom                	: renommeElementFinder 
Description       	: Renomme un élément du Finder (fichier/dossier/alias)
aliasElement 		: alias vers l'élément
nouveauNom	 	: nouveau nom de l'élément
retour			: RIEN
*)
on renommeElementFinder(aliasElement, nouveauNom)
	tell application "Finder"
		set name of aliasElement to nouveauNom
	end tell
end renommeElementFinder



(*
Nom                	: renommeApplication 
Description       	: Renomme une application du Finder
aliasElement 		: alias vers l'application
nouveauNom	 	: nouveau nom de l'application
retour			: RIEN
*)
on renommeApplication(aliasElement, nouveauNom)
	tell application "Finder"
		set name of aliasElement to nouveauNom & ".app"
	end tell
end renommeApplication


(*
Nom                	: dossierParent 
Description       	: Renvoi le dossier parent de l'élément passé en paramètre
aliasElement 		: alias vers l'élément
retour			: alias vers le dossier parent
*)
on dossierParent(monAlias)
	
	tell application "Finder" to set dossier to container of monAlias
	return (dossier as alias)
	
end dossierParent



(*
Nom                	: creeDossier 
Description       	: Crée un dossier
nomDossier 		: nom du dossier à créer
aliasDestination 	: alias vers l'endroit où créer le dossier
retour			: alias vers le dossier créé
*)
on creeDossier(nomDossier, aliasDestination)
	tell application "Finder"
		set monDossier to make new folder at aliasDestination with properties {name:nomDossier}
	end tell
	return monDossier as alias
end creeDossier


(*
Nom                	: creeAlias 
Description       	: Crée un raccourci (alias) vers un élément
aliasElement 		: alias vers l'élément
aliasDestination 	: alias vers l'endroit où créer le raccourci
retour			: alias vers le raccourci créé
*)
on creeAlias(aliasElement, aliasDestination)
	tell application "Finder"
		set monAlias to make new alias at aliasDestination to aliasElement
	end tell
	return monAlias as alias
end creeAlias


(*
Nom                	: copieDansDossier 
Description       	: Copie un élément dans un dossier
aliasACopier 		: alias vers l'élément à copier
aliasDestination 	: alias vers l'endroit où copier l'élément
retour			: alias vers l'élément copié
*)
on copieDansDossier(aliasACopier, aliasDossier)
	tell application "Finder"
		set fichierCopie to duplicate aliasACopier to aliasDossier
	end tell
	return fichierCopie as alias
end copieDansDossier

(*
Nom             : supprimeElement 
Description     : Supprime un élément
aliasElement 	: alias vers l'élément à supprimer
retour			: RIEN
*)
on supprimeElement(aliasElement)
	tell application "Finder" to delete aliasElement
end supprimeElement



-----------------------------------------------------------------------------------------------------------
--                                                     FIN
-----------------------------------------------------------------------------------------------------------


(*  

-- Caractéristiques de l'image créée

$ hdiutil info
framework       : 444.50.16
driver          : 10.12v444.50.16
================================================
image-path      : /Users/bruno/Desktop/Facture 1.2.4.dmg
image-alias     : /Users/bruno/Desktop/Facture 1.2.4.dmg
shadow-path     : <none>
icon-path       : /System/Library/PrivateFrameworks/DiskImages.framework/Resources/CDiskImage.icns
image-type      : lecture/écriture
system-image    : false
blockcount      : 6183
blocksize       : 512
writeable       : TRUE
autodiskmount   : TRUE
removable       : TRUE
image-encrypted : false
mounting user   : root
mounting mode   : <unknown>
process ID      : 99124
/dev/disk2	GUID_partition_scheme	
/dev/disk2s1	48465300-0000-11AA-AA11-00306543ECAC	/Volumes/Installez Facture 1.2.4
*)
