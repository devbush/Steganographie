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
#				     FICHIER DECODAGE					    #
#											    #
#			      UNIVERSITÉ DE STRASBOURG - L2S3				    #
#											    #
#############################################################################################

.data
input_file_msg:		.asciiz	"Input file name:\n"
input_file:		.space	128
header: 		.space   54
secret_msg:		.asciiz	"\nLe message secret est :\n"
input_err:		.asciiz "\nL'image n'existe pas ! Restarting...\n\n"
chariot:		.asciiz "\n"





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


	# Affiche secret_msg
	li		$v0, 4				# syscall 4, print string
	la		$a0, secret_msg			# Charge secret_msg string
	syscall


#############################################################################################
#											    #
#			  DECODAGE DU MESSAGE CODÉ DANS L'IMAGE				    #
#											    #
#############################################################################################
#											    #
# $s1 - Taille de la data section							    #
# $s2 - Début du tableau de pixel							    #
# $t0 - Compteur (Jusqu'à la taille de l'image ou huit 0 consécutif)			    #
# $t1 - Adresse du pixel courant							    #
# $t2 - Nouvelle valeur									    #
# $t3 - Caractère à l'indice courant							    #
# $t5 - Bit courant de ce caractère							    #
#											    #
#############################################################################################


init_loop:
	move		$t0, $zero			# Compteur à 0
	move		$t1, $s2			# Copie l'adresse du début du tableau dans $t2
	
loop:
	beq		$t0, $s1, loop_end		# Si $t0 == $s1, jump to loop_end
	addi		$t0, $t0, 1			# Incrémente le compteur
	
	loop_decode_init:
		li		$t4, 0
		li		$t6, 0			# Valeur ASCII du caractère courant du message codé
		li		$t5, 7
		li		$t8, 8
	
	loop_decode:
		beq		$t4, $t8, loop_decode_end
		
		lb		$t2, ($t1)		# Charge la couleur courante du pixel courant
		addi		$t1, $t1, 1		# Incrémente le compteur des pixels
		addi		$t4, $t4, 1		# Incrémente le compteur pour la valeur du caractère codé courant (entre 0 et 8)
		
		sll		$t2, $t2, 31		# Les deux shifts consécutifs de 31 bits
		srl		$t2, $t2, 31		# Permettent d'isoler le bit courant du caractère courant du message codé
		sllv		$t2, $t2, $t5		# Replace le bit courant à sa bonne position dans le caractère courant
		
		add		$t6, $t6, $t2		# Calcule la valeur ASCII du caractère courant du message codé
		subi		$t5, $t5, 1		# Décrémente le compteur pour placer le bit courant à sa bonne position
		
		bne		$t4, $t8, loop_decode	# Si $t4 != $t8, jump to loop_decode (début de la boucle)
		
	loop_decode_end:
		beqz		$t6, loop_end		# Si la valeur ASCII du caractère codé est 0 alors c'est la fin du message, jump to loop_end
							# Sinon affiche le caractère
		move		$a0, $t6		# Valeur ASCII du caractère courant du message codé
		li		$v0, 11			# syscall 11, print character
		syscall
		bnez		$t6, loop		# Si la valeur ASCII du caractère codé n'est pas 0, jump to loop (début de la boucle)

loop_end:

	# Affiche chariot (Retour chariot : '\n', c'est pour la cosmetique)
	li		$v0, 4				# syscall 4, print string
	la		$a0, chariot			# Charge chariot string
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
