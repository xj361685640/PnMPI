# This file is part of P^nMPI.
#
# Copyright (c)
#  2008-2017 Lawrence Livermore National Laboratories, United States of America
#  2011-2017 ZIH, Technische Universitaet Dresden, Federal Republic of Germany
#  2013-2017 RWTH Aachen University, Federal Republic of Germany
#
#
# P^nMPI is free software; you can redistribute it and/or modify it under the
# terms of the GNU Lesser General Public License as published by the Free
# Software Foundation version 2.1 dated February 1999.
#
# P^nMPI is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE. See the GNU Lesser General Public License for more
# details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with P^nMPI; if not, write to the
#
#   Free Software Foundation, Inc.
#   51 Franklin St, Fifth Floor
#   Boston, MA 02110, USA
#
#
# Written by Martin Schulz, schulzm@llnl.gov.
#
# LLNL-CODE-402774

find_package(Sanitizers)

#Add the target for the patcher
SET (PATCHER_FRONTEND_COMPILER "" CACHE FILEPATH "If this is a frontend/backend build use the backend compiler as CMake compilers and specify a frontend compiler here to create a frontend-operating version of the PnMPI patcher.")

SET (targetName pnmpi-patch)
if (PATCHER_FRONTEND_COMPILER)
   SET (targetName backend-pnmpi-patch)
endif()

add_executable(${targetName} patch.c)
add_coverage(${targetName})
add_sanitizers(${targetName})
if (BFD_FOUND)
  target_link_libraries(${targetName} ${BFD_LIBRARIES})
  target_link_libraries(${targetName} ${IBERTY_LIBRARIES})
endif()
install(TARGETS ${targetName} EXPORT ${targetName} RUNTIME DESTINATION bin)

# Allow patch target to be used by subprojects.
install(EXPORT ${targetName} DESTINATION share/cmake/PnMPI)

include_directories(${PROJECT_BINARY_DIR})

add_subdirectory(frontend)
