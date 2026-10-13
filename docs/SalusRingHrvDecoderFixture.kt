package com.rustnrum.healthyme.beta03

private fun pkt(index:Int, bytes: Map<Int,Int> = emptyMap()):ByteArray {
    val b=ByteArray(16)
    b[0]=57.toByte(); b[1]=index.toByte()
    for((i,v) in bytes) b[i]=v.toByte()
    b[15]=((0 until 15).sumOf { b[it].toInt() and 255 } and 255).toByte()
    return b
}
fun main(){
  val parser=SalusRingHrvLogDecoder()
  val midnight=1_700_000_000_000L
  val now=midnight+24*60*60*1000L
  check(parser.parse(pkt(0,mapOf(2 to 3,3 to 5)),midnight,now).isEmpty())
  check(parser.pageCount==3 && parser.rangeMinutes==5)
  val first=parser.parse(pkt(1,mapOf(2 to 4,3 to 56,4 to 57,14 to 59)),midnight,now)
  check(first.map{it.slot}==listOf(4,5,15))
  val second=parser.parse(pkt(2,mapOf(2 to 62,3 to 63,14 to 74)),midnight,now)
  check(second.map{it.slot}==listOf(16,17,28))
  val third=parser.parse(pkt(3,mapOf(2 to 75,14 to 76)),midnight,now)
  check(third.map{it.slot}==listOf(29,41) && parser.completed)
  check(parser.decoded==8)
  check(parser.parse(pkt(3,mapOf(2 to 55)),midnight,now).isEmpty())
  check(parser.invalidPackets==1)
  val corrupt=pkt(0,mapOf(2 to 2,3 to 10)); corrupt[15]=0
  check(parser.parse(corrupt,midnight,now).isEmpty())
  check(parser.invalidPackets==2)
  val future=SalusRingHrvLogDecoder()
  future.parse(pkt(0,mapOf(2 to 1,3 to 5)),midnight,midnight)
  check(future.parse(pkt(1,mapOf(2 to 1,3 to 30)),midnight,midnight).isEmpty())
  println("Kotlin fixture PASS: page boundaries, CRC, sequence, timestamps, missing/future values")
}
