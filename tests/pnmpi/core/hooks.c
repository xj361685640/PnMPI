/* This file is part of P^nMPI.
 *
 * Copyright (c)
 *  2008-2017 Lawrence Livermore National Laboratories, United States of America
 *  2011-2017 ZIH, Technische Universitaet Dresden, Federal Republic of Germany
 *  2013-2017 RWTH Aachen University, Federal Republic of Germany
 *
 *
 * P^nMPI is free software; you can redistribute it and/or modify it under the
 * terms of the GNU Lesser General Public License as published by the Free
 * Software Foundation version 2.1 dated February 1999.
 *
 * P^nMPI is distributed in the hope that it will be useful, but WITHOUT ANY
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
 * A PARTICULAR PURPOSE. See the GNU Lesser General Public License for more
 * details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with P^nMPI; if not, write to the
 *
 *   Free Software Foundation, Inc.
 *   51 Franklin St, Fifth Floor
 *   Boston, MA 02110, USA
 *
 *
 * Written by Martin Schulz, schulzm@llnl.gov.
 *
 * LLNL-CODE-402774
 */

/* This test case is used to check if PnMPI hits all hooks in modules.
 *
 * Note: This test cases check NOT, if the functionality of the specific hooks
 *       is correct, but only if they are called!
 */

#include <stdio.h> // printf

#include <pnmpi/hooks.h> // PnMPI header to check if the hooks signatures match.


#ifndef HOOKNAME
#define HOOKNAME unknown
#endif


void HOOKNAME()
{
  printf("%s hit.\n", __FUNCTION__);
}


/* CONFIGS: RegistrationPoint UnregistrationPoint Init Fini
 *
 * MODTYPE: XMPI
 *
 * PNMPICONF: module @MODNAME@
 *
 * ENVIRONMENT: PNMPI_LIB_PATH=@CMAKE_CURRENT_BINARY_DIR@
 * ENVIRONMENT: PNMPI_CONF=@PNMPICONF@
 * RUN: @MPIEXEC@ @MPIEXEC_NUMPROC_FLAG@ 1
 * RUN:   @MPIEXEC_PREFLAGS@ @TESTBIN_MPI_C@ @MPIEXEC_POSTFLAGS@
 *
 *
 * COMPILE_FLAGS-RegistrationPoint: -DHOOKNAME=PNMPI_RegistrationPoint
 * PASS-RegistrationPoint: PNMPI_RegistrationPoint hit.
 *
 * COMPILE_FLAGS-UnregistrationPoint: -DHOOKNAME=PNMPI_UnregistrationPoint
 * PASS-UnregistrationPoint: PNMPI_UnregistrationPoint hit.
 *
 * COMPILE_FLAGS-PNMPI_Init: -DHOOKNAME=PNMPI_Init
 * PASS-PNMPI_Init: PNMPI_Init hit.
 *
 * COMPILE_FLAGS-PNMPI_Fini: -DHOOKNAME=PNMPI_Fini
 * PASS-PNMPI_Fini: PNMPI_Fini hit.
 */
