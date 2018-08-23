#############################################################################################
#											    #
#				ARCHITECTURE DES ORDINATEURS				    #
#											    #
#					----------					    #
#											    #
#				   PROJET STEGANOGRAPHIE				    #
#											    #
#############################################################################################
#											    #
#		  LAFORÊT Nicolas			  MENY Alexandre		    #
#											    #
#				     FICHIER ENCODAGE					    #
#											    #
#			      UNIVERSITÉ DE STRASBOURG - L2S3				    #
#											    #
#############################################################################################

.data
input_file_msg:		.asciiz	"Input file name:\n"
input_file:		.space	128
header: 		.space   54
output_file_msg:	.asciiz	"\nOutput file name:\n"
output_file: 		.space  128
input_secret_msg:	.asciiz	"\nMessage secret :\n"
input_secret:		.space	128
input_err:		.asciiz "\nL'image n'existe pas ! Restarting...\n\n"
output_err: 		.asciiz "\nErreur sur le fichier de sortie ! Restarting...\n"


.text
main:

#############################################################################################
#											    #
#			OUVERTURE ET LECTURE DU FICHIER D'ENTRÉE			    #
#											    #
#############################################################################################
#											    #
#	$s0 - File descriptor								    #
#	$s1 - Taille de la data section							    #
#	$s2 - Tableau de pixel de l'image bmp						    #
#											    #
#############################################################################################

		
	# Affiche input_file_msg
	li		$v0, 4				# syscall 4, print string
	la		$a0, input_file_msg		# Charge input_file_msg string
	syscall
	
	# Read input_file
	li		$v0, 8				# syscall 8, read string
	la		$a0, input_file			# Stock le string dans input_file
	li		$a1, 128		
	syscall
	
remplace_loop_init:
	li		$t0, '\n'	
	li		$t1, 128			# Taille de input_file
	li		$t2, 0		
	
remplace_loop:
	beqz		$t1, remplace_loop_end		# Si fin du string, jump to loop end
	subu		$t1, $t1, 1			# Décrémentation de l'index
	lb		$t2, input_file($t1)		# Charge le caractère à la position de l'index courant
	bne		$t2, $t0, remplace_loop		# Si le caractère courant != '\n', jump au début de la boucle
	li		$t0, 0				# Sinon stock le caractère null
	sb		$t0, input_file($t1)		# Et remplace le '\n' par le caractère null
	
remplace_loop_end:
	
	# Open input_file
	li		$v0, 13				# syscall 13, open file
	la		$a0, input_file			# Charge l'adresse de input_file
	li 		$a1, 0				# Read flag
	li		$a2, 0				# Mode 0
	syscall
	bltz		$v0, inputFileError		# Si $v0=-1, alors il y a eu une erreur : jump a la fonction qui affiche le message d'erreur. 
	move		$s0, $v0			# Save file descriptor
	
	# Read header
	li		$v0, 14				# syscall 14, read from file
	move		$a0, $s0			# Charge le file descriptor
	la		$a1, header			# Charge l'adresse dans laquelle on veut stocker le header
	li		$a2, 54				# Read 54 octets
	syscall

	# Sauvegarde la taille
	lw		$s1, header+34			# Stock la taille de la data section de l'image
	
	# Read image data dans le tableau
	li		$v0, 9				# syscall 9, allocate heap memory
	move		$a0, $s1			# Taille de la data section
	syscall
	move		$s2, $v0			# Adresse du tableau de pixel dans $s2
	
	li		$v0, 14				# Read from file
	move		$a0, $s0			# Charge le file descriptor
	move		$a1, $s2			# Charge l'adress du tableau de pixel
	move		$a2, $s1			# Charge la taille de la data section
	syscall
	
	# Close file
	move		$a0, $s0			# Move le file descriptor dans $a0
	li		$v0, 16				# syscall 16, close file
	syscall


	# Affiche output_file_msg
	li		$v0, 4				# syscall 4, print string
	la		$a0, output_file_msg		# Charge output_file_msg string
	syscall
	
	# Read output_file
	li 		$v0, 8				# syscall 8, read string
	la 		$a0, output_file		# Stock le string dans output_file
	li 		$a1, 128		
	syscall
	
	# Remplace le '\n' par le caractère null
	li 		$t0, '\n'		
	li 		$t1, 128			# Taille de output_file
	li 		$t2, 0			
	
output_remplace_loop:
	beqz		$t1, remplace_loop_init		# Si fin du string, jump to remove newline from input string
	subu		$t1, $t1, 1			# Décrémentation de l'index
	lb		$t2, output_file($t1)		# Charge le caractère à la position de l'index courant
	bne		$t2, $t0, output_remplace_loop	# Si le caractère courant != '\n', jump to loop beginning
	li		$t0, 0				# Sinon stock le caractère null
	sb		$t0, output_file($t1)		# Et remplace le '\n' par le caractère null


	# Affiche input_secret_msg
	li		$v0, 4				# syscall 4, print string
	la		$a0, input_secret_msg		# Charge input_secret_msg
	syscall
	
	# Read input_secret
	li		$v0, 8				# syscall 8, read string
	la		$a0, input_secret		# Stock le string dans input_secret
	li		$a1, 128		
	syscall
	

#############################################################################################
#											    #
#			  ENCODAGE DU MESSAGE CODÉ DANS L'IMAGE				    #
#											    #
#############################################################################################
#											    #
# $s1 - Taille de la data section							    #
# $s2 - Début du tableau de pixel							    #
# $t0 - Compteur (Jusqu'à la taille du message secret ou le premier '\n' du message secret) #
# $t1 - Adresse du pixel courant							    #
# $t2 - Nouvelle valeur									    #
# $t3 - Caractère à l'indice courant							    #
# $t5 - Bit courant de ce caractère							    #
#											    #
#############################################################################################


init_loop:
	move		$t0, $zero			# Compteur à 0
	move		$t1, $s2			# Copie l'adresse du début du tableau pour pas le perdre avant d'écrire dans le fichier de sortie
	li		$t6, '\n'
	li		$t9, 128			# Taille de input_secret

loop_char:
	beq		$t0, $t9, loop_char_end
	lb		$t3, input_secret($t0)		# Charge le caractère à l'indice courant $t3
	addi		$t0, $t0, 1			# Incrémente le compteur
	
	beq		$t3, $t6, loop_char_end		# Si $t3 == '\n' alors jump à loop_char_end
	
	loop_bits_init:
		li		$t4, 0
		li		$t8, 7			# Compteur pour accéder à chaque bits du caractère avec les shift logiques
	
	loop_bits:
		blt		$t8, $t4, loop_bits_end	# Si $t8 < $t4, jump to loop_bits_end
		move		$t5, $t3
		srlv		$t5, $t5, $t8		# Place le $t8ieme bit en première position
		sll		$t5, $t5, 31		# Les deux shifts consécutifs de 31 bits
		srl		$t5, $t5, 31		# Permettent d'isoler le $t8ieme bit (qui a été placé en premier position)
		subi		$t8, $t8, 1		# Décrémente le compteur $t8
		
		# Chargement et isolation de la couleur courante du pixel courant
		lb 		$t2, ($t1)		# Charge la couleur courante du pixel courant dans $t2
		sll 		$t2, $t2, 24		# Les deux shifts consécutifs de 24 bits
		srl		$t2, $t2, 24		# Permettent d'isoler la couleur courante
		
		# Remplacement du bit de poids faible
		srl		$t2, $t2, 1		# Les deux shifts consécutifs de 1 bit
		sll		$t2, $t2, 1		# Permettent de mettre à 0 le bit de poids faible de la couleur courante
		add		$t2, $t2, $t5		# On ajoute le bit courant du caractère courant à la valeur de la couleur courante du pixel courant
		
		# Stock la nouvelle valeur dans le tableau de pixels
		sb		$t2, ($t1)
		addi		$t1, $t1, 1		# Incrémente le compteur (des pixels)
		
		bge		$t8, $t4, loop_bits	# Si $t8 >= $t4, jump to loop_bits (début de la boucle pour les bits du char)
		
	loop_bits_end:
	
	bne		$t3, $t6, loop_char		# Si $t3 != $t6, jump to loop_char (début de la boucle pour les char)


loop_char_end:
	li		$t4, 0
	li		$t8, 8	

loop_end:
	# Ajoute huit 0 après avoir écrit le message dans les bits de poids faible des couleurs des pixels
	# Nécessaire pour savoir quand s'arrêter lors du décodage du message
	beq		$t4, $t8, write_file
	subi		$t8, $t8, 1
	lb 		$t2, ($t1)
	sll 		$t2, $t2, 24
	srl		$t2, $t2, 24
	srl		$t2, $t2, 1
	sll		$t2, $t2, 1
	sb		$t2, ($t1)
	addi		$t1, $t1, 1
		
	bne		$t4, $t8, loop_end
		
	

#############################################################################################
#											    #
#		       OUVERTURE ET ECRITURE DANS LE FICHIER DE SORTIE			    #
#											    #
#############################################################################################
#											    #
#	$t1 - File descriptor fichier de sortie						    #
#	$s1 - Taille de la data section							    #
#	$s2 - Tableau de pixel de l'image bmp avec le message codé			    #
#											    #
#############################################################################################

write_file:
	
	# Open output_file
	li		$v0, 13				# syscall 13, open file
	la		$a0, output_file
	li		$a1, 1		
	li		$a2, 0
	syscall
	move		$t1, $v0			# Copie le file descriptor
	
	# Confirme que le fichier existe 
	bltz		$t1, outputFileError

	li		$v0, 15				# syscall 15, write to file
	move 		$a0, $t1
	la		$a1, header
	addi    	$a2, $zero,54
	syscall
	
	# Écrit dans output file
	li		$v0, 15				# syscall 15, write to file
	move 		$a0, $t1			# Charge le file descriptor
	la		$a1, ($s2)			# Charge l'adresse du tableau de pixel pour écrire dans le fichier de sortie
	move  		$a2, $s1			# Charge la taille de la data section de l'image de sortie
	syscall
	
	# Close file
	move		$a0, $t1
	li		$v0, 16				# syscall 16, close file
	syscall

Exit:
	# Quitte le programme
	li 		$v0, 10				# syscall 10, exit
	syscall
	
	
inputFileError:
	# Affiche input_err
	li		$v0, 4				# syscall 4, print string
	la		$a0, input_err			# Affiche le message
	syscall
	j		main				# Retourne au début du programme

outputFileError:
	# Affiche output_err
	li		$v0, 4				# syscall 4, print string
	la		$a0, output_err			# Affiche le message
	syscall
	j		main				# Retourne au début du programme
