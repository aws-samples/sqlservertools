@echo off
SET arg0=%0
SET arg1=%1
SET arg2=%2
SET arg3=%3
SET arg4=%4
SET arg5=%5
SET arg6=%6
SET arg7=%7
SET arg8=%8
SET arg9=%9
shift
shift
shift
shift
shift
shift
shift
shift
shift
SET arg10=%1
SET arg11=%2
SET arg12=%3

echo %arg0%
Powershell -ExecutionPolicy Bypass -file  C:.\AWSRecommendation.ps1 %arg1% %arg2% %arg3% %arg4% %arg5% %arg6% %arg7% %arg8% %arg9% %arg10%  %arg11% %arg12%     

